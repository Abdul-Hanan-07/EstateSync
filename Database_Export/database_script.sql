-- ==============================================================================
-- PROJECT: EstateSync (Smart Housing Society Management System)
-- GROUP: 6
-- DESCRIPTION: Complete Database Export (Structure, Data, Indexes, Constraints)
-- ==============================================================================

-- Setting up server SQL modes and starting the transaction for secure execution
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

-- ==============================================================================
-- PART 1: TABLE DEFINITIONS & DATA INSERTIONS
-- ==============================================================================

-- --------------------------------------------------------
-- Creates the audit_logs table to track system activities and changes securely
-- --------------------------------------------------------
CREATE TABLE `audit_logs` (
  `Log_ID` int(11) NOT NULL,
  `User_ID` int(11) DEFAULT NULL,
  `Action_Type` enum('INSERT','UPDATE','DELETE') NOT NULL,
  `Table_Affected` varchar(30) NOT NULL,
  `Old_Value` text DEFAULT NULL,
  `New_Value` text DEFAULT NULL,
  `Timestamp` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting historical audit logs into the system
INSERT INTO `audit_logs` (`Log_ID`, `User_ID`, `Action_Type`, `Table_Affected`, `Old_Value`, `New_Value`, `Timestamp`) VALUES
(1, 7, 'INSERT', 'BOOKINGS', 'None', 'Plot ID 10 booked', '2026-06-12 17:29:49'),
(2, 7, 'INSERT', 'PAYMENTS', 'None', 'New Payment rec-002', '2026-06-12 17:30:05'),
(3, 4, 'UPDATE', 'PAYMENTS', 'Pending', 'Approved', '2026-06-12 17:30:35'),
(4, 4, 'UPDATE', 'PLOTS', 'Previous Status', 'AVAILABLE', '2026-06-12 18:07:27'),
(5, 7, 'INSERT', 'BOOKINGS', 'None', 'Plot ID 16 booked', '2026-06-12 18:08:18'),
(6, 7, 'INSERT', 'PAYMENTS', 'None', 'New Payment rerr', '2026-06-12 18:08:32'),
(7, 7, 'UPDATE', 'SERVICE_BILLS', 'UNPAID', 'PAID', '2026-06-12 18:12:31'),
(8, 4, 'INSERT', 'SERVICE_BILLS', 'None', 'New Bill for Plot 4', '2026-06-12 18:18:26'),
(9, 7, 'UPDATE', 'SERVICE_BILLS', 'UNPAID', 'PAID', '2026-06-12 18:18:51'),
(10, 12, 'INSERT', 'BOOKINGS', 'None', 'Plot ID 11 booked', '2026-06-13 16:34:52'),
(11, 12, 'INSERT', 'PAYMENTS', 'None', 'New Payment rec-10', '2026-06-13 16:35:46'),
(12, 4, 'UPDATE', 'PAYMENTS', 'Pending', 'Approved', '2026-06-13 16:39:04'),
(13, 4, 'INSERT', 'SERVICE_BILLS', 'None', 'New Bill for Plot 11', '2026-06-13 16:41:28'),
(14, 12, 'UPDATE', 'SERVICE_BILLS', 'UNPAID', 'PAID', '2026-06-13 16:42:14');

-- --------------------------------------------------------
-- Creates the blocks table to define the different sectors in the society
-- --------------------------------------------------------
CREATE TABLE `blocks` (
  `Block_ID` int(11) NOT NULL,
  `Block_Name` varchar(50) NOT NULL,
  `Total_Plots` int(11) NOT NULL CHECK (`Total_Plots` >= 0),
  `Sector_Type` enum('RESIDENTIAL','COMMERCIAL','MIXED') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting predefined society blocks
INSERT INTO `blocks` (`Block_ID`, `Block_Name`, `Total_Plots`, `Sector_Type`) VALUES
(1, 'Rose', 10, 'RESIDENTIAL'),
(2, 'Jasmine', 8, 'RESIDENTIAL'),
(3, 'Lily', 6, 'RESIDENTIAL'),
(4, 'Orchid', 6, 'RESIDENTIAL');

-- --------------------------------------------------------
-- Creates the bookings table to link members to their purchased plots and plans
-- --------------------------------------------------------
CREATE TABLE `bookings` (
  `Booking_ID` int(11) NOT NULL,
  `Plot_ID` int(11) NOT NULL,
  `Member_ID` int(11) NOT NULL,
  `Plan_ID` int(11) NOT NULL,
  `Booking_Date` date NOT NULL,
  `Booking_Status` enum('ACTIVE','CANCELLED') NOT NULL DEFAULT 'ACTIVE'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting active plot bookings
INSERT INTO `bookings` (`Booking_ID`, `Plot_ID`, `Member_ID`, `Plan_ID`, `Booking_Date`, `Booking_Status`) VALUES
(5, 10, 6, 1, '2026-06-12', 'ACTIVE'),
(6, 16, 6, 1, '2026-06-12', 'ACTIVE'),
(7, 11, 13, 1, '2026-06-13', 'ACTIVE');

-- --------------------------------------------------------
-- Creates the contact_messages table to store queries sent from the website
-- --------------------------------------------------------
CREATE TABLE `contact_messages` (
  `Message_ID` int(11) NOT NULL,
  `Name` varchar(100) NOT NULL,
  `Email` varchar(100) NOT NULL,
  `Subject` varchar(200) NOT NULL,
  `Message` text NOT NULL,
  `Created_At` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting records of helpdesk messages
INSERT INTO `contact_messages` (`Message_ID`, `Name`, `Email`, `Subject`, `Message`, `Created_At`) VALUES
(1, 'Hanan', 'hanan@gmail.com', 'Billing Problem', 'We are Facing the billing Problem in website. \r\nKindly solve it as soon as possible.', '2026-06-12 13:43:18'),
(2, 'Hanan', 'hanan@gmail.com', 'Billing Problem', 'We are facing billing problem in website.\r\nKindly solve it as soon as possible.', '2026-06-12 13:44:48');

-- --------------------------------------------------------
-- Creates the installment_plans table to define the payment rules
-- --------------------------------------------------------
CREATE TABLE `installment_plans` (
  `Plan_ID` int(11) NOT NULL,
  `Plan_Name` varchar(50) NOT NULL,
  `Duration_Months` int(11) NOT NULL CHECK (`Duration_Months` > 0),
  `Number_of_Installments` int(11) NOT NULL CHECK (`Number_of_Installments` > 0),
  `Down_Payment_Percentage` decimal(5,2) NOT NULL CHECK (`Down_Payment_Percentage` between 0 and 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting the standard installment packages
INSERT INTO `installment_plans` (`Plan_ID`, `Plan_Name`, `Duration_Months`, `Number_of_Installments`, `Down_Payment_Percentage`) VALUES
(1, 'Standard Plan', 24, 24, 20.00),
(2, '1 Year Standard', 12, 12, 20.00);

-- --------------------------------------------------------
-- Creates the maintenance_services table to list extra society services
-- --------------------------------------------------------
CREATE TABLE `maintenance_services` (
  `Service_ID` int(11) NOT NULL,
  `Service_Name` varchar(50) NOT NULL,
  `Monthly_Rate` decimal(8,2) NOT NULL CHECK (`Monthly_Rate` >= 0),
  `Description` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting the available maintenance services
INSERT INTO `maintenance_services` (`Service_ID`, `Service_Name`, `Monthly_Rate`, `Description`) VALUES
(1, 'Security & Surveillance', 5000.00, '24/7 society security guards and CCTV maintenance.'),
(2, 'Waste Management', 2000.00, 'Daily door-to-door garbage collection and disposal.'),
(3, 'Parks & Landscaping', 1500.00, 'Maintenance of the Central Park and green belts.');

-- --------------------------------------------------------
-- Creates the members table to store personal resident details
-- --------------------------------------------------------
CREATE TABLE `members` (
  `Member_ID` int(11) NOT NULL,
  `Full_Name` varchar(100) NOT NULL,
  `CNIC` varchar(15) NOT NULL,
  `Email` varchar(100) DEFAULT NULL,
  `Phone_Number` varchar(15) DEFAULT NULL,
  `Permanent_Address` text DEFAULT NULL,
  `User_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting registered member profiles
INSERT INTO `members` (`Member_ID`, `Full_Name`, `CNIC`, `Email`, `Phone_Number`, `Permanent_Address`, `User_ID`) VALUES
(6, 'Ali', '34101-2008031-1', 'ali@gmail.com', NULL, NULL, 7),
(9, 'Abdul Hanan', '3460195679767', 'hanan@gmail.com', '03158111907', 'College Road, Daska, District Sialkot.', 10),
(11, 'System User', '34601-9567976-8', 'admin@estatesync.com', '0322-6018180', 'Not Provided', 4),
(12, 'Ahmad', '34601-956797-0', 'ahmad@gmail.com', '0326-109023', 'Maste City, Gujranwala', 11),
(13, 'Sufian', '34601-987654-4', 'sufi@gmail.com', '0300-2876432', 'Uni town, Gujreanwala', 12);

-- --------------------------------------------------------
-- Creates the payments table to track installment receipts against bookings
-- --------------------------------------------------------
CREATE TABLE `payments` (
  `Payment_ID` int(11) NOT NULL,
  `Booking_ID` int(11) NOT NULL,
  `Receipt_Number` varchar(30) NOT NULL,
  `Amount_Paid` decimal(12,2) NOT NULL CHECK (`Amount_Paid` > 0),
  `Payment_Date` date NOT NULL,
  `Payment_Mode` enum('BANK_CHALLAN','ONLINE_TRANSFER') NOT NULL,
  `Status` enum('Pending','Approved','Rejected') NOT NULL DEFAULT 'Pending'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting records of payments submitted by residents
INSERT INTO `payments` (`Payment_ID`, `Booking_ID`, `Receipt_Number`, `Amount_Paid`, `Payment_Date`, `Payment_Mode`, `Status`) VALUES
(2, 5, 'rec-002', 50000.00, '2026-06-12', 'BANK_CHALLAN', 'Approved'),
(3, 5, 'rerr', 9999999999.99, '2026-06-12', 'BANK_CHALLAN', 'Pending'),
(4, 7, 'rec-10', 500000.00, '2026-06-13', 'BANK_CHALLAN', 'Approved');

-- --------------------------------------------------------
-- Creates the plots table representing the society's property inventory
-- --------------------------------------------------------
CREATE TABLE `plots` (
  `Plot_ID` int(11) NOT NULL,
  `Block_ID` int(11) NOT NULL,
  `Plot_Number` varchar(10) NOT NULL,
  `Size_Marla` decimal(5,2) NOT NULL CHECK (`Size_Marla` > 0),
  `Category` enum('RESIDENTIAL','COMMERCIAL') NOT NULL,
  `Status` enum('AVAILABLE','SOLD','UNDER-CONSTRUCTION') NOT NULL DEFAULT 'AVAILABLE',
  `Total_Price` decimal(12,2) NOT NULL CHECK (`Total_Price` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting the complete inventory of society plots
INSERT INTO `plots` (`Plot_ID`, `Block_ID`, `Plot_Number`, `Size_Marla`, `Category`, `Status`, `Total_Price`) VALUES
(1, 1, 'A-01', 5.00, 'RESIDENTIAL', 'AVAILABLE', 2500000.00),
(2, 1, 'A-02', 5.00, 'RESIDENTIAL', 'AVAILABLE', 2500000.00),
(3, 1, 'A-03', 5.00, 'RESIDENTIAL', 'UNDER-CONSTRUCTION', 2500000.00),
(4, 1, 'A-04', 5.00, 'RESIDENTIAL', 'AVAILABLE', 2500000.00),
(5, 1, 'A-05', 10.00, 'RESIDENTIAL', 'SOLD', 4500000.00),
(6, 1, 'A-06', 10.00, 'RESIDENTIAL', 'AVAILABLE', 4500000.00),
(7, 1, 'A-07', 10.00, 'RESIDENTIAL', 'AVAILABLE', 4500000.00),
(8, 1, 'A-08', 5.00, 'RESIDENTIAL', 'SOLD', 2500000.00),
(9, 1, 'A-09', 5.00, 'RESIDENTIAL', 'UNDER-CONSTRUCTION', 2500000.00),
(10, 1, 'A-10', 5.00, 'RESIDENTIAL', 'SOLD', 2500000.00),
(11, 2, 'B-01', 8.00, 'RESIDENTIAL', 'SOLD', 3500000.00),
(12, 2, 'B-02', 8.00, 'RESIDENTIAL', 'SOLD', 3500000.00),
(13, 2, 'B-03', 8.00, 'RESIDENTIAL', 'AVAILABLE', 3500000.00),
(14, 2, 'B-04', 8.00, 'RESIDENTIAL', 'UNDER-CONSTRUCTION', 3500000.00),
(15, 2, 'B-05', 8.00, 'RESIDENTIAL', 'SOLD', 3500000.00),
(16, 2, 'B-06', 8.00, 'RESIDENTIAL', 'SOLD', 3500000.00),
(17, 2, 'B-07', 8.00, 'RESIDENTIAL', 'SOLD', 3500000.00),
(18, 2, 'B-08', 8.00, 'RESIDENTIAL', 'AVAILABLE', 3500000.00),
(19, 3, 'C-01', 10.00, 'RESIDENTIAL', 'AVAILABLE', 5000000.00),
(20, 3, 'C-02', 10.00, 'RESIDENTIAL', 'SOLD', 5000000.00),
(21, 3, 'C-03', 10.00, 'RESIDENTIAL', 'AVAILABLE', 5000000.00),
(22, 3, 'C-04', 10.00, 'RESIDENTIAL', 'UNDER-CONSTRUCTION', 5000000.00),
(23, 3, 'C-05', 10.00, 'RESIDENTIAL', 'SOLD', 5000000.00),
(24, 3, 'C-06', 10.00, 'RESIDENTIAL', 'AVAILABLE', 5000000.00),
(25, 4, 'D-01', 20.00, 'RESIDENTIAL', 'AVAILABLE', 9500000.00),
(26, 4, 'D-02', 20.00, 'RESIDENTIAL', 'SOLD', 9500000.00),
(27, 4, 'D-03', 20.00, 'RESIDENTIAL', 'AVAILABLE', 9500000.00),
(28, 4, 'D-04', 20.00, 'RESIDENTIAL', 'UNDER-CONSTRUCTION', 9500000.00),
(29, 4, 'D-05', 20.00, 'RESIDENTIAL', 'SOLD', 9500000.00),
(30, 4, 'D-06', 20.00, 'RESIDENTIAL', 'AVAILABLE', 9500000.00);

-- --------------------------------------------------------
-- Creates the service_bills table to issue monthly charges to residents
-- --------------------------------------------------------
CREATE TABLE `service_bills` (
  `Bill_ID` int(11) NOT NULL,
  `Plot_ID` int(11) NOT NULL,
  `Service_ID` int(11) NOT NULL,
  `Billing_Month` date NOT NULL,
  `Due_Date` date NOT NULL,
  `Amount_Due` decimal(8,2) NOT NULL CHECK (`Amount_Due` >= 0),
  `Issue_Status` enum('PAID','UNPAID') NOT NULL DEFAULT 'UNPAID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting generated maintenance bills
INSERT INTO `service_bills` (`Bill_ID`, `Plot_ID`, `Service_ID`, `Billing_Month`, `Due_Date`, `Amount_Due`, `Issue_Status`) VALUES
(4, 10, 1, '2026-06-01', '2026-06-20', 5000.00, 'PAID'),
(5, 10, 2, '2026-06-01', '2026-06-20', 2000.00, 'PAID'),
(7, 11, 1, '2026-07-01', '2026-07-09', 5000.00, 'PAID');

-- --------------------------------------------------------
-- Creates the users table to store system login credentials securely
-- --------------------------------------------------------
CREATE TABLE `users` (
  `User_ID` int(11) NOT NULL,
  `Email` varchar(100) NOT NULL,
  `Password` varchar(255) NOT NULL,
  `Role` enum('Admin','Resident') NOT NULL DEFAULT 'Resident'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Inserting encrypted user credentials for login
INSERT INTO `users` (`User_ID`, `Email`, `Password`, `Role`) VALUES
(4, 'admin@estatesync.com', 'scrypt:32768:8:1$Dp3TbvATgeckf3lj$74581509f4e52ba67993f4227aacab8ebc8ded84ad0b6a8cf68bacf030bdf839fa01e2f21c97ae52f53afe5e5423b9cea85c013f0950ce3af7de73733234720f', 'Admin'),
(7, 'ali@gmail.com', 'scrypt:32768:8:1$oAz9a56d8ghlKfQE$7ea2926cd6a7fd75276fa173dc482102aabb3985f8846b2f18c0efca816646d9ab758a0c20cc4c6b63f537d97a7e9362a5810fc040531beb8355ed2a90681027', 'Resident'),
(10, 'hanan@gmail.com', 'scrypt:32768:8:1$y2KyOwbohaGjsdAj$45df29cb05f21a50754217c23d5a6fded8eab0c9461ab8d3dda7a8b1d50c86515e6e25b8bc9991bbf91bdb9f4bea9313a016c4b8d17910be4eaef9a2b40523fa', 'Resident'),
(11, 'ahmad@gmail.com', 'scrypt:32768:8:1$cEwUr59vngPBk640$6964ede7f811e6607b1b60cd56ec3ee243dbbae8a1a17728e97f5376c2a9aaf3ee385150596bf5484e7989fcc3ec52eb0e0bbfeee8a93d73a82ff7a680525e2a', 'Resident'),
(12, 'sufi@gmail.com', 'scrypt:32768:8:1$MeCiSEbCeZAUpou5$c8a6ba4d52fa00a682aac50baff1ca7bd23b26b01ffb04a159d3943dc91f516f3596e77318c6a32d23436baaeb02e4eabaa747883601062757fbac8f49db0341', 'Resident');

-- ==============================================================================
-- PART 2: INDEXES, AUTO_INCREMENTS & CONSTRAINTS
-- ==============================================================================

-- Adding Primary and Unique Keys for data integrity
ALTER TABLE `audit_logs`
  ADD PRIMARY KEY (`Log_ID`);

ALTER TABLE `blocks`
  ADD PRIMARY KEY (`Block_ID`),
  ADD UNIQUE KEY `Block_Name` (`Block_Name`);

ALTER TABLE `bookings`
  ADD PRIMARY KEY (`Booking_ID`),
  ADD KEY `idx_plot_id` (`Plot_ID`),
  ADD KEY `Member_ID` (`Member_ID`),
  ADD KEY `Plan_ID` (`Plan_ID`);

ALTER TABLE `contact_messages`
  ADD PRIMARY KEY (`Message_ID`);

ALTER TABLE `installment_plans`
  ADD PRIMARY KEY (`Plan_ID`);

ALTER TABLE `maintenance_services`
  ADD PRIMARY KEY (`Service_ID`);

ALTER TABLE `members`
  ADD PRIMARY KEY (`Member_ID`),
  ADD UNIQUE KEY `CNIC` (`CNIC`),
  ADD UNIQUE KEY `Email` (`Email`),
  ADD KEY `fk_user_member` (`User_ID`);

ALTER TABLE `payments`
  ADD PRIMARY KEY (`Payment_ID`),
  ADD UNIQUE KEY `Receipt_Number` (`Receipt_Number`),
  ADD KEY `Booking_ID` (`Booking_ID`);

ALTER TABLE `plots`
  ADD PRIMARY KEY (`Plot_ID`),
  ADD UNIQUE KEY `uq_plot_block` (`Block_ID`,`Plot_Number`);

ALTER TABLE `service_bills`
  ADD PRIMARY KEY (`Bill_ID`),
  ADD UNIQUE KEY `uq_bill_month` (`Plot_ID`,`Service_ID`,`Billing_Month`),
  ADD KEY `Service_ID` (`Service_ID`);

ALTER TABLE `users`
  ADD PRIMARY KEY (`User_ID`),
  ADD UNIQUE KEY `Email` (`Email`);

ALTER TABLE `audit_logs`
  ADD KEY `idx_audit_user` (`User_ID`);


-- Setting Auto-Increment counters for Primary Keys
ALTER TABLE `audit_logs`
  MODIFY `Log_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

ALTER TABLE `blocks`
  MODIFY `Block_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

ALTER TABLE `bookings`
  MODIFY `Booking_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

ALTER TABLE `contact_messages`
  MODIFY `Message_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

ALTER TABLE `installment_plans`
  MODIFY `Plan_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

ALTER TABLE `maintenance_services`
  MODIFY `Service_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

ALTER TABLE `members`
  MODIFY `Member_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

ALTER TABLE `payments`
  MODIFY `Payment_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

ALTER TABLE `plots`
  MODIFY `Plot_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=44;

ALTER TABLE `service_bills`
  MODIFY `Bill_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

ALTER TABLE `users`
  MODIFY `User_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;


-- Applying Foreign Key Constraints to establish relationships
ALTER TABLE `bookings`
  ADD CONSTRAINT `bookings_ibfk_1` FOREIGN KEY (`Plot_ID`) REFERENCES `plots` (`Plot_ID`),
  ADD CONSTRAINT `bookings_ibfk_2` FOREIGN KEY (`Member_ID`) REFERENCES `members` (`Member_ID`),
  ADD CONSTRAINT `bookings_ibfk_3` FOREIGN KEY (`Plan_ID`) REFERENCES `installment_plans` (`Plan_ID`);

ALTER TABLE `members`
  ADD CONSTRAINT `fk_user_member` FOREIGN KEY (`User_ID`) REFERENCES `users` (`User_ID`) ON DELETE CASCADE;

ALTER TABLE `payments`
  ADD CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`Booking_ID`) REFERENCES `bookings` (`Booking_ID`);

ALTER TABLE `plots`
  ADD CONSTRAINT `plots_ibfk_1` FOREIGN KEY (`Block_ID`) REFERENCES `blocks` (`Block_ID`) ON DELETE CASCADE;

ALTER TABLE `service_bills`
  ADD CONSTRAINT `service_bills_ibfk_1` FOREIGN KEY (`Plot_ID`) REFERENCES `plots` (`Plot_ID`),
  ADD CONSTRAINT `service_bills_ibfk_2` FOREIGN KEY (`Service_ID`) REFERENCES `maintenance_services` (`Service_ID`);

ALTER TABLE `audit_logs`
  ADD CONSTRAINT `audit_logs_ibfk_1` FOREIGN KEY (`User_ID`) REFERENCES `users` (`User_ID`) ON DELETE SET NULL;

-- Performance indexes for frequently queried columns
ALTER TABLE `payments`
  ADD KEY `idx_payment_status` (`Status`);

ALTER TABLE `plots`
  ADD KEY `idx_plot_status` (`Status`);

ALTER TABLE `bookings`
  ADD KEY `idx_booking_status` (`Booking_Status`);

-- ==============================================================================
-- PART 3: DATABASE TRIGGERS FOR AUTOMATIC AUDIT LOGGING
-- ==============================================================================

DELIMITER //

-- Trigger: Automatically logs when a new booking is created
CREATE TRIGGER trg_booking_insert
AFTER INSERT ON bookings
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (User_ID, Action_Type, Table_Affected, Old_Value, New_Value, Timestamp)
    VALUES (NULL, 'INSERT', 'BOOKINGS', 'None', CONCAT('Booking ID ', NEW.Booking_ID, ' for Plot ID ', NEW.Plot_ID), NOW());
END //

-- Trigger: Automatically logs when a payment status changes
CREATE TRIGGER trg_payment_update
AFTER UPDATE ON payments
FOR EACH ROW
BEGIN
    IF OLD.Status != NEW.Status THEN
        INSERT INTO audit_logs (User_ID, Action_Type, Table_Affected, Old_Value, New_Value, Timestamp)
        VALUES (NULL, 'UPDATE', 'PAYMENTS', OLD.Status, NEW.Status, NOW());
    END IF;
END //

-- Trigger: Automatically logs when a plot status changes
CREATE TRIGGER trg_plot_update
AFTER UPDATE ON plots
FOR EACH ROW
BEGIN
    IF OLD.Status != NEW.Status THEN
        INSERT INTO audit_logs (User_ID, Action_Type, Table_Affected, Old_Value, New_Value, Timestamp)
        VALUES (NULL, 'UPDATE', 'PLOTS', OLD.Status, NEW.Status, NOW());
    END IF;
END //

-- Trigger: Automatically logs when a service bill is paid
CREATE TRIGGER trg_service_bill_update
AFTER UPDATE ON service_bills
FOR EACH ROW
BEGIN
    IF OLD.Issue_Status != NEW.Issue_Status THEN
        INSERT INTO audit_logs (User_ID, Action_Type, Table_Affected, Old_Value, New_Value, Timestamp)
        VALUES (NULL, 'UPDATE', 'SERVICE_BILLS', OLD.Issue_Status, NEW.Issue_Status, NOW());
    END IF;
END //

DELIMITER ;

-- ==============================================================================
-- PART 4: VIEWS FOR COMPACT AND USEFUL REPORTING
-- ==============================================================================

-- View: Society financial revenue summary by block
CREATE OR REPLACE VIEW view_society_revenue_summary AS
SELECT 
    b.Block_Name,
    b.Sector_Type,
    COUNT(p.Plot_ID) AS Total_Plots,
    SUM(CASE WHEN p.Status = 'SOLD' THEN 1 ELSE 0 END) AS Sold_Plots,
    COALESCE(SUM(pm.Amount_Paid), 0) AS Total_Revenue_Collected
FROM blocks b
LEFT JOIN plots p ON b.Block_ID = p.Block_ID
LEFT JOIN bookings bk ON p.Plot_ID = bk.Plot_ID AND bk.Booking_Status = 'ACTIVE'
LEFT JOIN payments pm ON bk.Booking_ID = pm.Booking_ID AND pm.Status = 'Approved'
GROUP BY b.Block_ID, b.Block_Name, b.Sector_Type;

-- View: Detailed booking audit sheet for admin dashboard
CREATE OR REPLACE VIEW view_active_bookings_details AS
SELECT 
    bk.Booking_ID,
    bk.Booking_Date,
    m.Full_Name AS Member_Name,
    m.CNIC AS Member_CNIC,
    p.Plot_Number,
    b.Block_Name,
    p.Size_Marla,
    p.Category AS Plot_Category,
    p.Total_Price,
    ip.Plan_Name AS Payment_Plan,
    COALESCE(SUM(pm.Amount_Paid), 0) AS Approved_Amount_Paid,
    (p.Total_Price - COALESCE(SUM(pm.Amount_Paid), 0)) AS Remaining_Balance
FROM bookings bk
JOIN plots p ON bk.Plot_ID = p.Plot_ID
JOIN blocks b ON p.Block_ID = b.Block_ID
JOIN members m ON bk.Member_ID = m.Member_ID
JOIN installment_plans ip ON bk.Plan_ID = ip.Plan_ID
LEFT JOIN payments pm ON bk.Booking_ID = pm.Booking_ID AND pm.Status = 'Approved'
WHERE bk.Booking_Status = 'ACTIVE'
GROUP BY bk.Booking_ID;

-- ==============================================================================
-- PART 5: STORED PROCEDURES FOR TRANSACTIONAL OPERATIONS
-- ==============================================================================

DELIMITER //

-- Procedure to safely book a plot and mark it sold in a transaction
CREATE PROCEDURE sp_book_plot(
    IN p_plot_id INT,
    IN p_member_id INT,
    IN p_plan_id INT,
    OUT p_success BOOLEAN
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
    END;

    START TRANSACTION;

    -- Check availability
    IF (SELECT Status FROM plots WHERE Plot_ID = p_plot_id) = 'AVAILABLE' THEN
        -- Insert booking
        INSERT INTO bookings (Plot_ID, Member_ID, Plan_ID, Booking_Date, Booking_Status)
        VALUES (p_plot_id, p_member_id, p_plan_id, CURDATE(), 'ACTIVE');

        -- Update plot status
        UPDATE plots SET Status = 'SOLD' WHERE Plot_ID = p_plot_id;

        COMMIT;
        SET p_success = TRUE;
    ELSE
        ROLLBACK;
        SET p_success = FALSE;
    END IF;
END //

DELIMITER ;

-- Committing the transaction
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;