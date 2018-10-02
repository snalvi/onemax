
# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

require 'faker'
require_relative '../models/nomination'
include Faker

5.times do
	tags = Faker::Name.name + ' ' + Faker::Name.name
	Nomination.create!({name: Faker::Name.name,
		description: Faker::Name.name,
		tags: tags,
		country: 'Canada',
		duas: Faker::Number.number(2).to_i,
		status: 'submitted'
	})
end
