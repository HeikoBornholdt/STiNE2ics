
##################################################
# @author Heiko Bornholdt <heikobornholdt@me.com>

NAME = ''
PASSWORD = ''

##################################################

require 'rubygems'
require 'httpclient'
require 'htmlentities'
require 'time'
require 'icalendar'

include Icalendar # Probably do this in your class to limit namespace overlap
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
arguments = result.header['REFRESH'].first.sub(/.*ARGUMENTS=(.+)/, '\\1')

# get courses
result = client.get('https://www.stine.uni-hamburg.de/scripts/mgrqispi.dll?APPNAME=CampusNet&PRGNAME=PROFCOURSES&ARGUMENTS=' + arguments)
result.body.scan(/(\?APPNAME=CampusNet&amp;PRGNAME=COURSEDETAILS[^"]+).*?>(.+)<\/a>/).each do |course,name|
  course = "#{course}" # TODO: there musst be a better way for casting to string!
  name = "#{name}" # TODO: there musst be a better way for casting to string!
  
  puts name

  # open course
  result = client.get(HTMLEntities.new.decode('https://www.stine.uni-hamburg.de/scripts/mgrqispi.dll' + course))

  # get events
  result.body.scan(/<li  class="courseListCell numout" title="(.*)" >/).each do |event|
    event = "#{event}" # TODO: there musst be a better way for casting to string!
    
    puts "\t" + event

    splits = event.split(/\//)
    times = splits[1].split(/-/)
    # translate german months
    splits[0] = splits[0].sub(/Mai/, 'May')
    splits[0] = splits[0].sub(/Dez/, 'Dec')
 
    startTime = splits[0] + times[0]
    endTime = splits[0] + times[1]
    location = splits[2]
    
    event = Event.new
    event.summary = name
    event.start = DateTime.parse(startTime)
    event.end = DateTime.parse(endTime)
    event.location = location
    calendar.add_event(event)
  end
end

# save into file
file = File.new("stine.ics", "w")
file.puts(calendar.to_ical)
file.close
puts File.dirname(__FILE__) + "/stine.ics"