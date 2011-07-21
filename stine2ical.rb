#!/usr/bin/env ruby
##################################################
# @author Heiko Bornholdt <heikobornholdt@me.com>
##################################################

require 'rubygems'
require 'highline/import'
require 'httpclient'
require 'htmlentities'
require 'icalendar'

NAME = ask("Enter your username: ") { |q| q.echo = true }
PASSWORD = ask("Enter your password (not shown on the screen): ") { |q| q.echo = "*" }




include Icalendar
calendar = Calendar.new

client = HTTPClient.new

# login
result = client.post('https://www.stine.uni-hamburg.de/scripts/mgrqispi.dll',
  :foolow_redirect => true,
  :body => {
  'APPNAME' => 'CampusNet',
  'ARGUMENTS' => 'clino,usrname,pass,menuno,persno,browser,platform',
  'PRGNAME' => 'LOGINCHECK',
  'browser' => '',
  'clino' => '<!$MG_SESSIONNO>',
  'menuno' => '<!$MG_MENUID>',
  'pass' => PASSWORD,
  'persno' => '00000000',
  'platform' => '',
  'submit' => 'Anmelden',
  'usrname' => NAME
 })


# read ARGUMENTS
begin
  arguments = result.header['REFRESH'].first.sub(/.*ARGUMENTS=(.+)/, '\\1')
rescue
  puts result.body.sub(/.*<h1>(.+)<\/h1>.*/, '\\1')
  exit
end


def translateToEnglishDate(string)
  string = string.sub(/Mai/, 'May')
  string = string.sub(/Dez/, 'Dec')
  return string
end

# get courses
result = client.get('https://www.stine.uni-hamburg.de/scripts/mgrqispi.dll?APPNAME=CampusNet&PRGNAME=PROFCOURSES&ARGUMENTS=' + arguments)
result.body.scan(/(\?APPNAME=CampusNet&amp;PRGNAME=COURSEDETAILS[^"]+).*?>(.+)<\/a>/).each do |course,name|
  course = course.to_s()
  name = name.to_s()  
#  puts name

  # open course
  result = client.get(HTMLEntities.new.decode('https://www.stine.uni-hamburg.de/scripts/mgrqispi.dll' + course))

  # get events
  result.body.scan(/<li  class="courseListCell numout" title="(.*)" >/).each do |event|
    event = event.to_s()    
    puts "\t" + event

    splits = event.split(/\//)
    times = splits[1].split(/-/)
    # translate german months
    splits[0] = translateToEnglishDate( splits[0] ) 

    startTime = splits[0] + times[0]
    endTime = splits[0] + times[1]
    location = splits[2]

    puts startTime +"<-"

    event = Event.new
    event.summary = name
    event.start = DateTime.parse(startTime)
    event.end = DateTime.parse(endTime)
    event.location = location
    calendar.add_event(event)
  end
end

# get exams
result = client.get('https://www.stine.uni-hamburg.de/scripts/mgrqispi.dll?APPNAME=CampusNet&PRGNAME=MYEXAMS&ARGUMENTS=' + arguments)
result.body.scan(/<tr>.*?<a.*?>(.*?)<\/a>.*?<a.*?>(.*?)<\/a>.*?<a.*?>(.*?)<\/a>.*?<\/tr>/m).each do |modullong,modulshort,date|
 
  name = modullong.to_s()
  
  startTime = translateGermanMonths( date.sub(/[a-z]{2}, (.*?) (..:..)-(..:..)/im, '\\1  \\2:00') )
  endTime =   translateGermanMonths( date.sub(/[a-z]{2}, (.*?) (..:..)-(..:..)/im, '\\1  \\3:00') )

  puts startTime
  puts endTime

  event = Event.new
  event.summary = name + "(Klausur)"
  event.start = DateTime.parse(startTime)
  event.end = DateTime.parse(endTime)
  calendar.add_event(event)
end

# save into file
filename = 'stine.ics'
file = File.new(filename, 'w')
file.puts(calendar.to_ical)
file.close
puts 'The events has been written to: ' + File.dirname(__FILE__) + '/' + filename

