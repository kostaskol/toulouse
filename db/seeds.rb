# db:prepare seeds a newly created database, production included.
load Rails.root.join("db/seeds/development.rb") if Rails.env.development?
