CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE nonzerotable (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    age INT NOT NULL
);
