CREATE TABLE `schema_migrations`(`filename` varchar(255) NOT NULL PRIMARY KEY);
CREATE TABLE `users`(
  `id` integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  `cpf` varchar(255) NOT NULL UNIQUE,
  `created_at` timestamp NOT NULL
);
CREATE TABLE `certificates`(
  `id` integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  `user_id` integer NOT NULL REFERENCES `users`,
  `fingerprint` varchar(255) NOT NULL UNIQUE,
  `kind` varchar(255) NOT NULL,
  `cnpj` varchar(255),
  `subject` varchar(255) NOT NULL,
  `not_after` timestamp NOT NULL,
  `status` varchar(255) NOT NULL,
  `approvable_after` timestamp,
  `created_at` timestamp NOT NULL,
  `last_used_at` timestamp
);
CREATE TABLE `challenges`(
  `id` varchar(255) NOT NULL PRIMARY KEY,
  `challenge` varchar(255) NOT NULL,
  `expires_at` timestamp NOT NULL,
  `used_at` timestamp
);
CREATE TABLE `sessions`(
  `id` integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  `user_id` integer NOT NULL REFERENCES `users`,
  `certificate_id` integer NOT NULL REFERENCES `certificates`,
  `token_digest` varchar(255) NOT NULL UNIQUE,
  `expires_at` timestamp NOT NULL,
  `created_at` timestamp NOT NULL
);
CREATE TABLE `profiles`(
  `id` integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  `user_id` integer NOT NULL REFERENCES `users`,
  `kind` varchar(255) NOT NULL,
  `document` varchar(255) NOT NULL,
  `name` varchar(255),
  `settings` varchar(255) DEFAULT('{}') NOT NULL,
  `next_invoice_number` integer DEFAULT(1) NOT NULL,
  `created_at` timestamp NOT NULL,
  UNIQUE(`user_id`, `document`)
);
CREATE TABLE `dps_counters`(
  `profile_id` integer NOT NULL REFERENCES `profiles`,
  `environment` varchar(255) NOT NULL,
  `serie` varchar(255) NOT NULL,
  `next_number` integer NOT NULL,
  PRIMARY KEY(`profile_id`, `environment`, `serie`)
);
CREATE TABLE `templates`(
  `id` integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  `profile_id` integer NOT NULL REFERENCES `profiles`,
  `kind` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `body` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL
);
CREATE TABLE `invoices`(
  `id` integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  `profile_id` integer NOT NULL REFERENCES `profiles`,
  `number` integer NOT NULL,
  `params` varchar(255) NOT NULL,
  `pdf` blob NOT NULL,
  `created_at` timestamp NOT NULL,
  UNIQUE(`profile_id`, `number`)
);
CREATE TABLE `dps`(
  `id` integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  `profile_id` integer NOT NULL REFERENCES `profiles`,
  `invoice_id` integer NOT NULL REFERENCES `invoices`,
  `environment` varchar(255) NOT NULL,
  `serie` varchar(255) NOT NULL,
  `n_dps` integer NOT NULL,
  `dps_id` varchar(255) NOT NULL UNIQUE,
  `state` varchar(255) NOT NULL,
  `unsigned_xml` varchar(255) NOT NULL,
  `signed_xml` varchar(255),
  `nfse_xml` varchar(255),
  `chave_acesso` varchar(255),
  `messages` varchar(255),
  `pdf` blob,
  `created_at` timestamp NOT NULL,
  `updated_at` timestamp NOT NULL,
  UNIQUE(`profile_id`, `environment`, `serie`, `n_dps`)
);
INSERT INTO schema_migrations (filename) VALUES
('20261126192757_create_schema.rb');
