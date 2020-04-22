# -*- encoding : utf-8 -*-
# == Schema Information
#
# Table name: spam_addresses
#
#  id         :integer          not null, primary key
#  email      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class SpamAddress < ApplicationRecord
  validates_presence_of :email, :message => 'Please enter the email address to mark as spam'
  validates_uniqueness_of :email, :message => 'This address is already marked as spam'

  before_save :downcase_email

  def self.spam?(email_address)
    exists?(email: Array(email_address).compact.map(&:downcase))
  end

  private

  def downcase_email
    email.downcase!
  end
end
