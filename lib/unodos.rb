require 'matrix'
require "unodos/version"
require "unodos/infinite"
module Unodos
  def self.[](*list)
    Unodos::Infinite.new(list)
  end
end
