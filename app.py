import os
from datetime import datetime, timedelta
from dotenv import load_dotenv  # type: ignore
from flask import Flask, render_template, request, redirect, flash, session, jsonify, url_for  # type: ignore
import mysql.connector  # type: ignore
from functools import wraps
import random
from werkzeug.security import generate_password_hash, check_password_hash  # type: ignore
from flask_wtf.csrf import CSRFProtect  # type: ignore

load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', os.urandom(24))

csrf = CSRFProtect(app)

MIN_PASSWORD_LENGTH = 8
MAX_LOGIN_ATTEMPTS = 5
LOGIN_LOCKOUT_MINUTES = 5
# in-memory login attempt tracker: email -> {'count': int, 'locked_until': datetime|None}
# resets on app restart and isn't shared across multiple worker processes,
# but is enough to slow down naive brute-force attempts for this project's scale
login_attempts = {}

# db connection setup
def get_db_connection():
    return mysql.connector.connect(
        host=os.environ.get('DB_HOST', 'localhost'),
        user=os.environ.get('DB_USER', 'root'),
        password=os.environ.get('DB_PASSWORD', ''),
        database=os.environ.get('DB_NAME', 'estatesync')
    )

# function to save audit logs
def log_audit(user_id, action, table, old_val, new_val):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO AUDIT_LOGS (User_ID, Action_Type, Table_Affected, Old_Value, New_Value)
            VALUES (%s, %s, %s, %s, %s)
        ''', (user_id, action, table, str(old_val), str(new_val)))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Audit Log Error: {e}")

# custom decorators to protect routes
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'loggedin' not in session:
            flash("Please login to access this page.", "warning")
            return redirect('/login')
        return f(*args, **kwargs)
    return decorated_function

def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'loggedin' not in session or session.get('role') != 'Admin':
            flash("Admin access required.", "danger")
            return redirect('/')
        return f(*args, **kwargs)
    return decorated_function

# home page
@app.route('/')
def index():
    return render_template('index.html')

# load society map and plot details
@app.route('/map')
def society_map():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM BLOCKS ORDER BY Block_Name")
    blocks = cursor.fetchall()
    plots_data = {}
    for block in blocks:
        cursor.execute("""
            SELECT Plot_ID, Block_ID, Plot_Number, Size_Marla, Category, Status, Total_Price 
            FROM PLOTS WHERE Block_ID = %s ORDER BY Plot_Number
        """, (block['Block_ID'],))
        plots_data[block['Block_ID']] = cursor.fetchall()
    cursor.execute("SELECT * FROM INSTALLMENT_PLANS")
    plans = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('map.html', blocks=blocks, plots_data=plots_data, plans=plans)

# plot booking logic
@app.route('/request_booking', methods=['POST'])
@login_required
def request_booking():
    if session.get('role') != 'Resident': return redirect('/')
    plot_id = request.form['plot_id']
    plan_id = request.form['plan_id']
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT Member_ID FROM MEMBERS WHERE Email = %s", (session['email'],))
        member = cursor.fetchone()
        
        # checking if member exists before booking
        if not member:
            flash("Error: Member profile not found. Please contact administration.", "danger")
            return redirect('/map')
            
        # call stored procedure to book plot in a secure database transaction
        cursor.execute("SET @success = 0;")
        cursor.execute("CALL sp_book_plot(%s, %s, %s, @success);", (int(plot_id), int(member['Member_ID']), int(plan_id)))
        # retrieve output parameter
        cursor.execute("SELECT @success;")
        success_res = cursor.fetchone()
        
        # MySQL Cursor returns dictionary if dictionary=True, let's get the value
        is_success = False
        if success_res:
            # if dictionary=True, keys are column names (e.g. '@success')
            is_success = list(success_res.values())[0] if isinstance(success_res, dict) else success_res[0]
            
        if is_success:
            conn.commit()
            log_audit(session.get('user_id'), 'INSERT', 'BOOKINGS', 'None', f'Plot {plot_id} booked')
            flash("Plot successfully booked!", "success")
            return redirect('/resident')
        else:
            flash("Booking failed. Plot might no longer be available.", "warning")
            return redirect('/map')
    except Exception as e:
        flash("Error processing booking request.", "danger")
        return redirect('/map')
    finally:
        cursor.close()
        conn.close()

# admin rejects a payment
@app.route('/reject_payment/<int:payment_id>', methods=['POST'])
@admin_required
def reject_payment(payment_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE PAYMENTS SET Status = 'Rejected' WHERE Payment_ID = %s", (payment_id,))
        log_audit(session.get('user_id'), 'UPDATE', 'PAYMENTS', f'Pending (Payment ID {payment_id})', 'Rejected')
        conn.commit()
        flash("Payment rejected.", "danger")
    except Exception as e:
        flash("Error rejecting payment.", "danger")
    finally:
        cursor.close()
        conn.close()
    return redirect('/admin')

# update plot status
@app.route('/update_plot/<int:plot_id>', methods=['POST'])
@admin_required
def update_plot(plot_id):
    new_status = request.form.get('status')
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT Status FROM PLOTS WHERE Plot_ID = %s", (plot_id,))
        old_plot = cursor.fetchone()
        old_status = old_plot[0] if old_plot else 'Unknown'
        cursor.execute("UPDATE PLOTS SET Status = %s WHERE Plot_ID = %s", (new_status, plot_id))
        log_audit(session.get('user_id'), 'UPDATE', 'PLOTS', old_status, new_status)
        conn.commit()
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})
    finally:
        cursor.close()
        conn.close()
    return jsonify({'success': True})

# resident dashboard
@app.route('/resident')
@login_required
def resident_dashboard():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM MEMBERS WHERE Email = %s", (session['email'],))
    member = cursor.fetchone()
    bookings, payments = [], []
    if member:
        cursor.execute("""
            SELECT b.*, p.Plot_Number, p.Size_Marla, p.Total_Price, bl.Block_Name, ip.Plan_Name, ip.Duration_Months,
                   COALESCE((SELECT SUM(Amount_Paid) FROM PAYMENTS WHERE Booking_ID = b.Booking_ID AND Status = 'Approved'), 0) AS Total_Paid
            FROM BOOKINGS b
            JOIN PLOTS p ON b.Plot_ID = p.Plot_ID
            JOIN BLOCKS bl ON p.Block_ID = bl.Block_ID
            JOIN INSTALLMENT_PLANS ip ON b.Plan_ID = ip.Plan_ID
            WHERE b.Member_ID = %s AND b.Booking_Status = 'ACTIVE'
        """, (member['Member_ID'],))
        bookings = cursor.fetchall()
        if bookings:
            booking_ids = [b['Booking_ID'] for b in bookings]
            format_strings = ','.join(['%s'] * len(booking_ids))
            cursor.execute(f"SELECT * FROM PAYMENTS WHERE Booking_ID IN ({format_strings}) ORDER BY Payment_Date DESC", tuple(booking_ids))
            payments = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('resident.html', member=member, bookings=bookings, payments=payments)

# submit new payment
@app.route('/submit_payment', methods=['POST'])
@login_required
def submit_payment():
    booking_id = request.form['booking_id']
    receipt = request.form['receipt_num']
    mode = request.form['payment_mode']

    try:
        amount = float(request.form['amount'])
        if amount <= 0 or amount > 9999999999:
            flash("Invalid payment amount.", "danger")
            return redirect('/resident')
    except ValueError:
        flash("Invalid payment amount.", "danger")
        return redirect('/resident')

    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Check if the booking belongs to the logged-in resident
        cursor.execute("SELECT Member_ID FROM MEMBERS WHERE Email = %s", (session['email'],))
        member = cursor.fetchone()
        if not member:
            flash("Error: Member profile not found.", "danger")
            return redirect('/resident')
            
        cursor.execute("SELECT 1 FROM BOOKINGS WHERE Booking_ID = %s AND Member_ID = %s AND Booking_Status = 'ACTIVE'", (booking_id, member[0]))
        if not cursor.fetchone():
            flash("Unauthorized request.", "danger")
            return redirect('/resident')

        cursor.execute("INSERT INTO PAYMENTS (Booking_ID, Receipt_Number, Amount_Paid, Payment_Date, Payment_Mode, Status) VALUES (%s, %s, %s, CURDATE(), %s, 'Pending')", (booking_id, receipt, amount, mode))
        log_audit(session.get('user_id'), 'INSERT', 'PAYMENTS', 'None', f'New Payment {receipt}')
        conn.commit()
        flash("Payment submitted!", "success")
    except Exception as e:
        flash("Error submitting payment.", "danger")
    finally:
        cursor.close()
        conn.close()
    return redirect('/resident')

# admin dashboard
@app.route('/admin')
@admin_required
def admin_dashboard():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    # fetch all pending payments
    cursor.execute('''
        SELECT p.Payment_ID, m.Full_Name, m.CNIC, p.Amount_Paid, p.Payment_Mode, p.Status, p.Receipt_Number
        FROM PAYMENTS p
        JOIN BOOKINGS b ON p.Booking_ID = b.Booking_ID
        JOIN MEMBERS m ON b.Member_ID = m.Member_ID
        WHERE p.Status = 'Pending'
        ORDER BY p.Payment_Date DESC
    ''')
    pending_payments = cursor.fetchall()
    
    # fetch users and profiles
    cursor.execute('''
        SELECT u.User_ID, u.Email, u.Role, m.Full_Name, m.CNIC, m.Phone_Number, m.Permanent_Address 
        FROM USERS u
        LEFT JOIN MEMBERS m ON u.User_ID = m.User_ID
        ORDER BY u.User_ID DESC
    ''')
    users = cursor.fetchall()
    
    # load contact messages
    contact_messages = []
    try:
        cursor.execute("SELECT * FROM contact_messages ORDER BY Message_ID DESC")
        contact_messages = cursor.fetchall()
    except Exception as e:
        print(f"Database Error loading messages: {e}") 
    
    # stats for admin dashboard
    cursor.execute("SELECT COUNT(*) as total FROM PLOTS")
    total_plots = cursor.fetchone()['total']
    
    cursor.execute("SELECT COUNT(*) as total FROM PLOTS WHERE Status = 'SOLD'")
    sold_plots = cursor.fetchone()['total']
    
    cursor.execute("SELECT COUNT(*) as total FROM MEMBERS")
    total_members = cursor.fetchone()['total']
    
    cursor.execute("SELECT SUM(Amount_Paid) as total FROM PAYMENTS WHERE Status = 'Approved'")
    revenue = cursor.fetchone()['total'] or 0
    
    # retrieve summary from SQL View
    block_summary = []
    try:
        cursor.execute("SELECT * FROM view_society_revenue_summary")
        block_summary = cursor.fetchall()
    except Exception as e:
        print(f"Database View Error: {e}")
        
    cursor.close()
    conn.close()
    
    return render_template('admin.html', 
                           pending_payments=pending_payments, 
                           users=users,
                           contact_messages=contact_messages,
                           block_summary=block_summary,
                           stats={
                               'total_plots': total_plots,
                               'sold_plots': sold_plots,
                               'total_members': total_members,
                               'revenue': revenue
                           })

# approve payment
@app.route('/approve_payment/<int:payment_id>', methods=['POST'])
@admin_required
def approve_payment(payment_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE PAYMENTS SET Status = 'Approved' WHERE Payment_ID = %s", (payment_id,))
        log_audit(session.get('user_id'), 'UPDATE', 'PAYMENTS', f'Pending (Payment ID {payment_id})', 'Approved')
        conn.commit()
        flash("Payment approved!", "success")
    except Exception as e:
        flash("Error approving payment.", "danger")
    finally:
        cursor.close()
        conn.close()
    return redirect('/admin')

# login logic
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email, password, role = request.form['email'], request.form['password'], request.form['role']

        # block login attempts while locked out from too many recent failures
        attempt = login_attempts.get(email)
        if attempt and attempt['locked_until'] and datetime.now() < attempt['locked_until']:
            wait_minutes = int((attempt['locked_until'] - datetime.now()).total_seconds() // 60) + 1
            flash(f"Too many failed login attempts. Try again in {wait_minutes} minute(s).", "danger")
            return render_template('login.html')

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute('SELECT * FROM USERS WHERE Email = %s AND Role = %s', (email, role))
        user = cursor.fetchone()
        cursor.close()
        conn.close()

        # checking the hashed password
        if user and check_password_hash(user['Password'], password):
            login_attempts.pop(email, None)
            session.update({'loggedin': True, 'user_id': user['User_ID'], 'email': email, 'role': role})
            return redirect('/admin' if role == 'Admin' else '/resident')

        # track the failed attempt and lock out after too many
        attempt = login_attempts.setdefault(email, {'count': 0, 'locked_until': None})
        attempt['count'] += 1
        if attempt['count'] >= MAX_LOGIN_ATTEMPTS:
            attempt['locked_until'] = datetime.now() + timedelta(minutes=LOGIN_LOCKOUT_MINUTES)
            attempt['count'] = 0
        flash("Invalid credentials.", "danger")
    return render_template('login.html')

# resident services / bills
@app.route('/resident_services')
@login_required
def resident_services():
    if session.get('role') != 'Resident': 
        return redirect('/')
        
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    cursor.execute("SELECT Member_ID FROM MEMBERS WHERE Email = %s", (session['email'],))
    member = cursor.fetchone()
    
    bills = []
    if member:
        # get bills for resident's active plots
        cursor.execute("""
            SELECT sb.*, ms.Service_Name, p.Plot_Number, b.Block_Name
            FROM SERVICE_BILLS sb
            JOIN MAINTENANCE_SERVICES ms ON sb.Service_ID = ms.Service_ID
            JOIN PLOTS p ON sb.Plot_ID = p.Plot_ID
            JOIN BLOCKS b ON p.Block_ID = b.Block_ID
            JOIN BOOKINGS bk ON p.Plot_ID = bk.Plot_ID
            WHERE bk.Member_ID = %s AND bk.Booking_Status = 'ACTIVE'
            ORDER BY sb.Due_Date DESC
        """, (member['Member_ID'],))
        bills = cursor.fetchall()
        
    cursor.close()
    conn.close()
    return render_template('resident_services.html', bills=bills)

# pay a bill
@app.route('/pay_bill/<int:bill_id>', methods=['POST'])
@login_required
def pay_bill(bill_id):
    if session.get('role') != 'Resident': 
        return redirect('/')
        
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Check if the bill belongs to this resident
        cursor.execute("SELECT Member_ID FROM MEMBERS WHERE Email = %s", (session['email'],))
        member = cursor.fetchone()
        
        if not member:
            flash("Profile not found.", "danger")
            return redirect('/resident_services')
            
        cursor.execute("""
            SELECT 1 FROM SERVICE_BILLS sb
            JOIN PLOTS p ON sb.Plot_ID = p.Plot_ID
            JOIN BOOKINGS bk ON p.Plot_ID = bk.Plot_ID
            WHERE sb.Bill_ID = %s AND bk.Member_ID = %s AND bk.Booking_Status = 'ACTIVE'
        """, (bill_id, member[0]))
        
        if not cursor.fetchone():
            flash("Unauthorized request.", "danger")
            return redirect('/resident_services')

        cursor.execute("UPDATE SERVICE_BILLS SET Issue_Status = 'PAID' WHERE Bill_ID = %s", (bill_id,))
        log_audit(session.get('user_id'), 'UPDATE', 'SERVICE_BILLS', 'UNPAID', 'PAID')
        conn.commit()
        flash("Service bill paid successfully!", "success")
    except Exception as e:
        flash("Error processing payment.", "danger")
    finally:
        cursor.close()
        conn.close()
        
    return redirect('/resident_services')

# admin services page
@app.route('/admin_services')
@admin_required
def admin_services():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    # get available services
    cursor.execute("SELECT * FROM MAINTENANCE_SERVICES")
    services = cursor.fetchall()

    # get booked plots
    cursor.execute("""
        SELECT p.Plot_ID, p.Plot_Number, b.Block_Name, m.Full_Name
        FROM PLOTS p
        JOIN BLOCKS b ON p.Block_ID = b.Block_ID
        JOIN BOOKINGS bk ON p.Plot_ID = bk.Plot_ID
        JOIN MEMBERS m ON bk.Member_ID = m.Member_ID
        WHERE bk.Booking_Status = 'ACTIVE'
    """)
    booked_plots = cursor.fetchall()

    # get all bills
    cursor.execute("""
        SELECT sb.*, ms.Service_Name, p.Plot_Number, b.Block_Name, m.Full_Name
        FROM SERVICE_BILLS sb
        JOIN MAINTENANCE_SERVICES ms ON sb.Service_ID = ms.Service_ID
        JOIN PLOTS p ON sb.Plot_ID = p.Plot_ID
        JOIN BLOCKS b ON p.Block_ID = b.Block_ID
        JOIN BOOKINGS bk ON p.Plot_ID = bk.Plot_ID
        JOIN MEMBERS m ON bk.Member_ID = m.Member_ID
        WHERE bk.Booking_Status = 'ACTIVE'
        ORDER BY sb.Due_Date DESC
    """)
    all_bills = cursor.fetchall()

    cursor.close()
    conn.close()
    return render_template('admin_services.html', services=services, booked_plots=booked_plots, all_bills=all_bills)

# admin generates a new bill
@app.route('/generate_bill', methods=['POST'])
@admin_required
def generate_bill():
    plot_id = request.form['plot_id']
    service_id = request.form['service_id']
    billing_month = request.form['billing_month'] + '-01'
    due_date = request.form['due_date']
    amount = request.form['amount']

    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO SERVICE_BILLS (Plot_ID, Service_ID, Billing_Month, Due_Date, Amount_Due, Issue_Status)
            VALUES (%s, %s, %s, %s, %s, 'UNPAID')
        """, (plot_id, service_id, billing_month, due_date, amount))
        
        log_audit(session.get('user_id'), 'INSERT', 'SERVICE_BILLS', 'None', f'New Bill for Plot {plot_id}')
        conn.commit()
        flash("Service bill generated and sent to resident successfully!", "success")
    except mysql.connector.Error as err:
        flash("Error generating bill. Ensure this bill doesn't already exist for this month.", "danger")
    finally:
        cursor.close()
        conn.close()
        
    return redirect('/admin_services')

# user profile
@app.route('/profile')
@login_required
def profile():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute('''
        SELECT u.Email as Login_Email, u.Role, m.* FROM USERS u 
        LEFT JOIN MEMBERS m ON u.User_ID = m.User_ID 
        WHERE u.User_ID = %s
    ''', (session['user_id'],))
    user_data = cursor.fetchone()
    cursor.close()
    conn.close()
    
    return render_template('profile.html', user=user_data)

# update user profile
@app.route('/update_profile', methods=['POST'])
@login_required
def update_profile():
    if session.get('role') != 'Resident':
        flash("Profile update is only available for residents.", "warning")
        return redirect('/profile')
        
    name = request.form.get('name')
    phone = request.form.get('phone')
    address = request.form.get('address')
    
    if not name or not phone or not address:
        flash("All fields are required.", "danger")
        return redirect('/profile')
        
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Get old values for logging
        cursor.execute("SELECT Full_Name, Phone_Number, Permanent_Address FROM MEMBERS WHERE User_ID = %s", (session['user_id'],))
        old_data = cursor.fetchone()
        
        cursor.execute("""
            UPDATE MEMBERS 
            SET Full_Name = %s, Phone_Number = %s, Permanent_Address = %s 
            WHERE User_ID = %s
        """, (name, phone, address, session['user_id']))
        
        # log audit
        old_val = f"Name: {old_data[0]}, Phone: {old_data[1]}, Address: {old_data[2]}" if old_data else "None"
        new_val = f"Name: {name}, Phone: {phone}, Address: {address}"
        log_audit(session.get('user_id'), 'UPDATE', 'MEMBERS', old_val, new_val)
        
        conn.commit()
        flash("Profile updated successfully!", "success")
    except Exception as e:
        flash(f"Error updating profile: {str(e)}", "danger")
    finally:
        cursor.close()
        conn.close()
        
    return redirect('/profile')

# signup logic
@app.route('/signup', methods=['GET', 'POST'])
def signup():
    if request.method == 'POST':
        name = request.form.get('name')
        email = request.form['email']
        password = request.form['password']
        role = 'Resident'  # Public signup is always Resident
        
        cnic = request.form.get('cnic', '')
        phone = request.form.get('phone', '')
        address = request.form.get('address', '')

        if not password or len(password) < MIN_PASSWORD_LENGTH:
            flash(f"Password must be at least {MIN_PASSWORD_LENGTH} characters long.", "danger")
            return redirect('/signup')

        # hash the password securely
        hashed_pw = generate_password_hash(password)
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            # insert user
            cursor.execute('INSERT INTO USERS (Email, Password, Role) VALUES (%s, %s, %s)', (email, hashed_pw, role))
            user_id = cursor.lastrowid
            
            # insert member details
            if role == 'Resident':
                cursor.execute('INSERT INTO MEMBERS (User_ID, Full_Name, CNIC, Phone_Number, Email, Permanent_Address) VALUES (%s, %s, %s, %s, %s, %s)', 
                               (user_id, name, cnic, phone, email, address))
            
            conn.commit()
            flash("Account created! Please login.", "success")
            return redirect('/login')
        except mysql.connector.Error as err:
            flash("Error: Email or CNIC already registered.", "danger")
            return redirect('/signup')
        finally:
            cursor.close()
            conn.close()
    return render_template('signup.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect('/')

# contact us form
@app.route('/contact', methods=['GET', 'POST'])
def contact():
    if request.method == 'POST':
        name = request.form['name'][:100]
        email = request.form['email'][:100]
        subject = request.form['subject'][:200]
        msg = request.form['message'][:500]
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute('INSERT INTO CONTACT_MESSAGES (Name, Email, Subject, Message) VALUES (%s, %s, %s, %s)', (name, email, subject, msg))
            conn.commit()
            flash("Message sent successfully!", "success")
        except Exception as e:
            flash("Error sending message. Please try again.", "danger")
        finally:
            cursor.close()
            conn.close()
    return render_template('contactus.html')

@app.route('/privacy')
def privacy():
    return render_template('privacy.html')

@app.context_processor
def inject_request():
    return dict(request=request)

# view audit logs
@app.route('/audit')
@admin_required
def view_audit_logs():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    logs = []
    try:
        cursor.execute("SELECT * FROM AUDIT_LOGS ORDER BY Timestamp DESC")
        logs = cursor.fetchall()
    except Exception as e:
        flash("Error loading audit logs.", "danger")
    finally:
        cursor.close()
        conn.close()
    return render_template('audit.html', logs=logs)

if __name__ == '__main__':
    debug_mode = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    app.run(debug=debug_mode)