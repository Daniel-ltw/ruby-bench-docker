# This file belongs in the discourse repo, but this is
# a (modified) copy because we need a fix that
# has not landed in stable yet https://github.com/discourse/discourse/commit/819d4facda2192b64dc18d874ff52c22ec157f71
# Once that commit is in stable, remove this file and references to it in the Dockerfile and runner files



# can be used to generate a mock db for profiling purposes

# we want our script to generate a consistent output, to do so
#  we monkey patch array sample so it always uses the same rng
class Array
  RNG = Random.new(1098109928029800)

  def sample
    self[RNG.rand(size)]
  end
end

# based on https://gist.github.com/zaius/2643079
def unbundled_require(gem)
  if defined?(::Bundler)
    spec_path = Dir.glob("#{Gem.dir}/specifications/#{gem}-*.gemspec").last
    if spec_path.nil?
      raise LoadError
    end

    spec = Gem::Specification.load spec_path
    spec.activate
  end

  begin
    require gem
  end
end

def sentence
  @gabbler ||= Gabbler.new.tap do |gabbler|
    story = File.read(File.dirname(__FILE__) + "/alice.txt")
    gabbler.learn(story)
  end

  sentence = ""
  until sentence.length > 800 do
    sentence << @gabbler.sentence
    sentence << "\n"
  end
  sentence
end

def create_admin(seq)
  User.new.tap { |admin|
    admin.email = "admin@localhost#{seq}.fake"
    admin.username = "admin#{seq}"
    admin.password = "password12345abc"
    admin.save!
    admin.grant_admin!
    admin.change_trust_level!(TrustLevel[4])
    admin.activate
  }
end

require File.expand_path(File.dirname(__FILE__) + "/../config/environment")

SiteSetting.queue_jobs = false

unless Rails.env == "profile"
  puts "This script should only be used in the profile environment"
  exit
end

def ensure_perf_test_topic_has_right_title!
  t = Topic.find(179)
  t.title = "I am a topic used for perf tests"
  t.save! if t.title_changed?
end

# by default, Discourse has a "system" and `discobot` account
if User.count > 2
  puts "Only run this script against an empty DB"

  ensure_perf_test_topic_has_right_title!
  exit
end

require 'optparse'
begin
  unbundled_require 'gabbler'
rescue LoadError
  puts "installing gabbler gem"
  puts `gem install gabbler`
  unbundled_require 'gabbler'
end

puts "Creating 100 users"
users = 100.times.map do |i|
  putc "."
  create_admin(i)
end

puts
puts "Creating 10 categories"
categories = 10.times.map do |i|
  putc "."
  Category.create(name: "category#{i}", text_color: "ffffff", color: "000000", user: users.first)
end

puts
puts "Creating 100 topics"

topic_ids = 100.times.map do
  post = PostCreator.create(users.sample, raw: sentence, title: sentence[0..50].strip, category:  categories.sample.name, skip_validations: true)

  putc "."
  post.topic_id
end

puts
puts "creating 2000 replies"
2000.times do
  putc "."
  PostCreator.create(users.sample, raw: sentence, topic_id: topic_ids.sample, skip_validations: true)
end

# no sidekiq so update some stuff
Category.update_stats
Jobs::PeriodicalUpdates.new.execute(nil)

ensure_perf_test_topic_has_right_title!
