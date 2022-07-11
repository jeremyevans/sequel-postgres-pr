require_relative '../postgres-pr/connection'

Sequel::Postgres::PGError = PostgresPR::PGError
Sequel::Postgres::PGconn = PostgresPR::Connection
Sequel::Postgres::PGresult = PostgresPR::Result
