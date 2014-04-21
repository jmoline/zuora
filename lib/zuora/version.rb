require 'scanf'

module Zuora
  class Version
    MAJOR = 0
    MINOR = 0
    PATCH = 11

    def self.to_s
      "#{MAJOR}.#{MINOR}.#{PATCH}"
    end
  end
end
