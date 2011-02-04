require 'json'
require 'state_machine'
require 'dm-migrations'
require 'dm-timestamps'

require 'config/stompbox'

class Push
  include DataMapper::Resource

  property :id,         Serial
  property :status,     String
  property :payload,    Text, :required => true, :lazy => false
  property :created_at, DateTime

  has n, :deployments

  attr_accessor :parsed_payload

  state_machine :status, :initial => :received do

    event :deploy do
      transition all - [:deploying, :deployed] => :deploying
    end

    before_transition :on => :deploy do 
      Push.undeploy_everything
    end

    event :deployed do
      transition :deploying => :deployed
    end

    event :failed do
      transition all => :failed
    end

    event :undeploy do
      transition :deployed => :undeployed
    end

  end

  def [](property)
    parse_payload[property]
  end

  def repo_url
    self['repository']['url']
  end

  def repo_name
    self['repository']['name']
  end

  def self.deployed
    Push.all(:status=>:deployed)
  end

  protected
  def parse_payload
    @parsed_payload ||= JSON.parse(self.payload)
  end

  def self.undeploy_everything
    Push.deployed.each do |p|
      p.undeploy
    end
  end

end

class Deployment
  include DataMapper::Resource

  property :id, Serial
  property :created_at, DateTime
  property :undeployed_at, DateTime

  belongs_to :push

end

DataMapper.auto_upgrade!
