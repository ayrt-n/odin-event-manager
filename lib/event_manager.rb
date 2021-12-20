require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def standardize_phone_number(number)
  number = number.gsub(/[^\d]/, '')
  number.to_i.to_s
end

def clean_phone_number(number)
  number = standardize_phone_number(number)

  if number.length == 10
    number
  elsif number.length == 11 && number[0] == '1'
    number[1..10]
  else
    '0000000000'
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representative by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def largest_hash_keys(hash)
  max_val = hash.values.max
  hash.select { |key, val| val == max_val }.keys
end

def array_to_string_list(arr)
  if arr.length > 2
    arr_final = arr.pop
    arr.join(', ') + "and #{arr_final}"
  else
    arr.join(' and ')
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open('event_attendees.csv', 
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)

reg_hour_count = Hash.new(0)
reg_weekday_count = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  reg_date = Time.strptime(row[:regdate], "%m/%d/%y %k:%M")
  reg_hour = reg_date.strftime("%k:00")
  reg_weekday = reg_date.strftime("%A")

  reg_hour_count[reg_hour] += 1
  reg_weekday_count[reg_weekday] += 1
end

most_popular_hours = largest_hash_keys(reg_hour_count)
most_popular_days = largest_hash_keys(reg_weekday_count)

puts "The most popular hour was #{array_to_string_list(most_popular_hours)} " +
      "with #{reg_hour_count[most_popular_hours[0]]} registrations"

puts "The most popular day was #{array_to_string_list(most_popular_days)} " +
      "with #{reg_weekday_count[most_popular_days[0]]} registrations"
