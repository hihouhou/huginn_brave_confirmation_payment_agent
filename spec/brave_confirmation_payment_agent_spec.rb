require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::BraveConfirmationPaymentAgent do
  before(:each) do
    @valid_options = Agents::BraveConfirmationPaymentAgent.new.default_options
    @checker = Agents::BraveConfirmationPaymentAgent.new(:name => "BraveConfirmationPaymentAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
