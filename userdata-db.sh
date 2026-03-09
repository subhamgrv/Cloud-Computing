#!/bin/bash
set -e

apt-get update
apt-get -y install mariadb-server

# Start and enable MariaDB
systemctl start mariadb
systemctl enable mariadb

# Update bind-address to allow external connections
sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mariadb

# Create DB, user, and initialize schema
cat <<EOF | mysql -u root
CREATE DATABASE IF NOT EXISTS registrysystem;

CREATE USER IF NOT EXISTS 'Admin'@'%' IDENTIFIED BY 'abcd@1234';
GRANT ALL PRIVILEGES ON registrysystem.* TO 'Admin'@'%';
FLUSH PRIVILEGES;

USE registrysystem;

CREATE TABLE IF NOT EXISTS usertype (
  id TINYINT NOT NULL,
  label VARCHAR(50) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO usertype (id, label) VALUES
  (1, 'Administrator'),
  (2, 'Doctor'),
  (3, 'OST'),
  (4, 'Researcher'),
  (5, 'Insurer');

CREATE TABLE IF NOT EXISTS userprofile (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(100),
  email VARCHAR(100),
  password VARCHAR(100),
  user_type TINYINT,
  active TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY email (email),
  KEY fk_userprofile_usertype (user_type),
  CONSTRAINT fk_userprofile_usertype FOREIGN KEY (user_type)
    REFERENCES usertype(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS patientdata (
  id INT NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  insurance_number VARCHAR(50),
  insurance_provider VARCHAR(50),
  date_of_birth DATE,
  phone_number VARCHAR(20),
  agree_tc TINYINT(1),
  pincode INT,
  source INT,
  PRIMARY KEY (id),
  KEY fk_source_user (source),
  CONSTRAINT fk_source_user FOREIGN KEY (source) REFERENCES userprofile(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS medical_data (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  personal_information LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  clinical_finding LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  foot_status LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  foot_status_graphics LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  additional_information LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  categorization_according_to_risk_groups LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  criteria_for_high_level_care LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  shoe_supply_according_to_risk_group LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  other_information LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  patient_id INT DEFAULT NULL,
  PRIMARY KEY (id),
  KEY fk_patient (patient_id),
  CONSTRAINT fk_patient FOREIGN KEY (patient_id) REFERENCES patientdata(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mos_survey (
  id INT NOT NULL AUTO_INCREMENT,
  survey_id BIGINT DEFAULT NULL,
  phone_number VARCHAR(20) NOT NULL,
  pre_completed TINYINT(1) DEFAULT 0,
  post_completed TINYINT(1) DEFAULT 0,
  agree_to_terms TINYINT(1) DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  pre_walking_distance VARCHAR(100),
  pre_walking_distance_formatted VARCHAR(100),
  pre_illnesses TEXT,
  pre_illnesses_formatted TEXT,
  pre_has_wounds_ulcers TINYINT(1),
  pre_has_wounds_ulcers_formatted VARCHAR(100),
  pre_expect_fewer_wounds VARCHAR(100),
  pre_expect_fewer_wounds_formatted VARCHAR(255),
  pre_doctor_listened_rating TINYINT,
  pre_doctor_listened_rating_formatted VARCHAR(255),
  pre_doctor_explained VARCHAR(100),
  pre_doctor_explained_formatted VARCHAR(255),
  pre_doctor_expectation_adjustment VARCHAR(100),
  pre_doctor_expectation_adjustment_formatted VARCHAR(255),
  pre_technician_listened_rating TINYINT,
  pre_technician_listened_rating_formatted VARCHAR(255),
  pre_technician_explained VARCHAR(100),
  pre_technician_explained_formatted VARCHAR(255),
  pre_technician_expectation_adjustment VARCHAR(100),
  pre_technician_expectation_adjustment_formatted VARCHAR(255),
  pre_expect_shoe_appearance TINYINT,
  pre_expect_shoe_appearance_formatted VARCHAR(255),
  pre_others_judgement VARCHAR(100),
  pre_others_judgement_formatted VARCHAR(255),
  pre_involved_in_shoe_design TINYINT(1),
  pre_involved_in_shoe_design_formatted VARCHAR(255),
  pre_expect_shoe_fit TINYINT,
  pre_expect_shoe_fit_formatted VARCHAR(255),
  pre_expected_walking_with_shoes VARCHAR(100),
  pre_expected_walking_with_shoes_formatted VARCHAR(255),
  pre_compare_walking_distance VARCHAR(50),
  pre_compare_walking_distance_formatted VARCHAR(255),
  pre_expected_activity_change TEXT,
  pre_expected_activity_change_formatted TEXT,
  pre_priority_design_or_problem VARCHAR(50),
  pre_priority_design_or_problem_formatted VARCHAR(255),
  pre_advantage_vs_disadvantage TINYINT,
  pre_advantage_vs_disadvantage_formatted VARCHAR(255),
  pre_comments TEXT,
  pre_completion_time_minutes INT,
  post_walking_distance VARCHAR(100),
  post_walking_distance_formatted VARCHAR(255),
  post_walking_ability_change VARCHAR(100),
  post_walking_ability_change_formatted VARCHAR(255),
  post_health_improvement VARCHAR(100),
  post_health_improvement_formatted VARCHAR(255),
  post_has_wounds_ulcers TINYINT(1),
  post_has_wounds_ulcers_formatted VARCHAR(100),
  post_wound_ulcer_change TEXT,
  post_wound_ulcer_change_formatted TEXT,
  post_shoe_appearance TINYINT,
  post_shoe_appearance_formatted VARCHAR(255),
  post_others_view VARCHAR(100),
  post_others_view_formatted VARCHAR(255),
  post_shoe_fit TINYINT,
  post_shoe_fit_formatted VARCHAR(255),
  post_fit_expectation TINYINT,
  post_fit_expectation_formatted VARCHAR(255),
  post_walkability_rating TINYINT,
  post_walkability_rating_formatted VARCHAR(255),
  post_walkability_expectation TINYINT,
  post_walkability_expectation_formatted VARCHAR(255),
  post_shoe_weight_feel TINYINT,
  post_shoe_weight_feel_formatted VARCHAR(255),
  post_shoe_weight_expectation TINYINT,
  post_shoe_weight_expectation_formatted VARCHAR(255),
  post_donning_doffing TINYINT,
  post_donning_doffing_formatted VARCHAR(255),
  post_activities_change TEXT,
  post_activities_change_formatted TEXT,
  post_wear_frequency VARCHAR(100),
  post_wear_frequency_formatted VARCHAR(255),
  post_wear_hours VARCHAR(100),
  post_wear_hours_formatted VARCHAR(255),
  post_wear_as_expected VARCHAR(50),
  post_wear_as_expected_formatted VARCHAR(255),
  post_wear_satisfaction TINYINT,
  post_wear_satisfaction_formatted VARCHAR(255),
  post_doctor_listened_rating TINYINT,
  post_doctor_listened_rating_formatted VARCHAR(255),
  post_technician_listened_rating TINYINT,
  post_technician_listened_rating_formatted VARCHAR(255),
  post_priority_design_or_problem VARCHAR(50),
  post_priority_design_or_problem_formatted VARCHAR(255),
  post_advantages TEXT,
  post_disadvantages TEXT,
  post_advantage_vs_disadvantage TINYINT,
  post_advantage_vs_disadvantage_formatted VARCHAR(255),
  post_goal_met VARCHAR(50),
  post_goal_met_formatted VARCHAR(255),
  post_goal_not_met_reason TEXT,
  post_usability_rating TEXT,
  post_usability_factors TEXT,
  post_additional_comments TEXT,
  post_completion_time_minutes INT,
  PRIMARY KEY (id),
  UNIQUE KEY survey_id (survey_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO userprofile (name, email, password, user_type, active)
VALUES (
  'Administrator',
  'administrator@hs-fulda.de',
  'Password1234',
  1,
  TRUE
);
EOF


#userdata-db.sh.tpl