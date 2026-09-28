-- =====================================================================
-- Inventory Management System : schema
-- Target : MySQL 8.x (written for MySQL Command Line Client 8.4)
-- All data in this project is fictional sample data.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS inventory_demo
    DEFAULT CHARACTER SET utf8mb4;
USE inventory_demo;

-- ---------------------------------------------------------------------
-- Dimension tables
-- ---------------------------------------------------------------------
CREATE TABLE cities (
    city_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    city_name   VARCHAR(60)  NOT NULL,
    PRIMARY KEY (city_id),
    UNIQUE KEY uq_city_name (city_name)
) ENGINE=InnoDB;

CREATE TABLE offices (
    office_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    office_name VARCHAR(80)  NOT NULL,
    city_id     INT UNSIGNED NOT NULL,
    PRIMARY KEY (office_id),
    UNIQUE KEY uq_office_name (office_name),
    CONSTRAINT fk_office_city FOREIGN KEY (city_id) REFERENCES cities (city_id)
) ENGINE=InnoDB;

CREATE TABLE categories (
    category_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    category_name VARCHAR(60)  NOT NULL,
    PRIMARY KEY (category_id),
    UNIQUE KEY uq_category_name (category_name)
) ENGINE=InnoDB;

CREATE TABLE vendors (
    vendor_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    vendor_name VARCHAR(100) NOT NULL,
    PRIMARY KEY (vendor_id),
    UNIQUE KEY uq_vendor_name (vendor_name)
) ENGINE=InnoDB;

CREATE TABLE items (
    item_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    item_name   VARCHAR(100) NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    unit        VARCHAR(20)  NOT NULL,          -- e.g. pcs, box, litre
    unit_price  DECIMAL(10,2) NOT NULL,         -- standard price per unit
    PRIMARY KEY (item_id),
    UNIQUE KEY uq_item_name (item_name),
    CONSTRAINT fk_item_category FOREIGN KEY (category_id) REFERENCES categories (category_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Transaction tables
-- ---------------------------------------------------------------------

-- Stock on hand at the start of the reporting period, per office and item
CREATE TABLE opening_stock (
    office_id  INT UNSIGNED NOT NULL,
    item_id    INT UNSIGNED NOT NULL,
    quantity   INT NOT NULL,
    as_of_date DATE NOT NULL,
    PRIMARY KEY (office_id, item_id),
    CONSTRAINT fk_os_office FOREIGN KEY (office_id) REFERENCES offices (office_id),
    CONSTRAINT fk_os_item   FOREIGN KEY (item_id)   REFERENCES items (item_id)
) ENGINE=InnoDB;

CREATE TABLE purchases (
    purchase_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    purchase_date DATE NOT NULL,
    vendor_id     INT UNSIGNED NOT NULL,
    office_id     INT UNSIGNED NOT NULL,
    item_id       INT UNSIGNED NOT NULL,
    quantity      INT NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (purchase_id),
    KEY idx_pur_date (purchase_date),
    KEY idx_pur_office_item (office_id, item_id),
    CONSTRAINT fk_pur_vendor FOREIGN KEY (vendor_id) REFERENCES vendors (vendor_id),
    CONSTRAINT fk_pur_office FOREIGN KEY (office_id) REFERENCES offices (office_id),
    CONSTRAINT fk_pur_item   FOREIGN KEY (item_id)   REFERENCES items (item_id),
    CONSTRAINT chk_pur_qty   CHECK (quantity > 0)
) ENGINE=InnoDB;

CREATE TABLE consumption (
    consumption_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    consumption_date DATE NOT NULL,
    office_id        INT UNSIGNED NOT NULL,
    item_id          INT UNSIGNED NOT NULL,
    quantity_used    INT NOT NULL,
    PRIMARY KEY (consumption_id),
    KEY idx_con_date (consumption_date),
    KEY idx_con_office_item (office_id, item_id),
    CONSTRAINT fk_con_office FOREIGN KEY (office_id) REFERENCES offices (office_id),
    CONSTRAINT fk_con_item   FOREIGN KEY (item_id)   REFERENCES items (item_id),
    CONSTRAINT chk_con_qty   CHECK (quantity_used > 0)
) ENGINE=InnoDB;

CREATE TABLE stock_transfers (
    transfer_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    transfer_date  DATE NOT NULL,
    item_id        INT UNSIGNED NOT NULL,
    from_office_id INT UNSIGNED NOT NULL,
    to_office_id   INT UNSIGNED NOT NULL,
    quantity       INT NOT NULL,
    PRIMARY KEY (transfer_id),
    KEY idx_tr_date (transfer_date),
    CONSTRAINT fk_tr_item FOREIGN KEY (item_id) REFERENCES items (item_id),
    CONSTRAINT fk_tr_from FOREIGN KEY (from_office_id) REFERENCES offices (office_id),
    CONSTRAINT fk_tr_to   FOREIGN KEY (to_office_id)   REFERENCES offices (office_id),
    CONSTRAINT chk_tr_qty CHECK (quantity > 0),
    CONSTRAINT chk_tr_diff CHECK (from_office_id <> to_office_id)
) ENGINE=InnoDB;
