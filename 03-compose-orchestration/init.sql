-- Database initialization script
-- This script runs when the PostgreSQL container starts for the first time

-- Create additional databases if needed
-- CREATE DATABASE test_db;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS logs;

-- Create indexes for better performance
-- These will be created when tables are created by the application

-- Insert some sample data for demonstration
-- This will be done by the application

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE webapp TO admin;
GRANT ALL PRIVILEGES ON SCHEMA public TO admin;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO admin;
GRANT ALL PRIVILEGES ON SCHEMA logs TO admin;

-- Create a read-only user for reporting
CREATE USER readonly_user WITH PASSWORD 'readonly123';
GRANT CONNECT ON DATABASE webapp TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create some utility functions
CREATE OR REPLACE FUNCTION get_database_size() 
RETURNS TEXT AS $$
BEGIN
    RETURN pg_size_pretty(pg_database_size(current_database()));
END;
$$ LANGUAGE plpgsql;

-- Log the initialization
DO $$
BEGIN
    RAISE NOTICE 'Database initialized successfully at %', NOW();
END $$;