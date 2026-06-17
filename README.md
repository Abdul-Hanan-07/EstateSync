# EstateSync - Smart Housing Society Management System 🏙️

A fully digitized, relational database-driven web application designed to manage housing society operations, plot bookings, and financial tracking. Built during my 4th Semester Database Systems course.

## 🚀 Features
- **Role-Based Access Control (RBAC):** Distinct dashboards for Administrators and Residents.
- **Interactive Plot Management:** Real-time tracking of available, sold, and under-construction plots.
- **Automated Billing System:** Dynamically generates and tracks monthly maintenance bills.
- **Immutable Audit Trail:** Database-level SQL triggers automatically log all system actions.

## 🛠️ Technology Stack
- **Backend:** Python Flask
- **Database:** MySQL (Strict 3NF Normalization)
- **Frontend:** HTML5, CSS3, Bootstrap 5, Jinja2 Templating

## ⚙️ Database Architecture
The system relies on a highly normalized relational database featuring:
- Complex multi-table Equijoins for dynamic dashboard data.
- Aggregate functions for real-time society revenue analytics.
- Password hashing (scrypt) for secure user authentication.
