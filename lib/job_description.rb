class JobDescription
  attr_reader :url, :site, :type
  attr_accessor :failures, :level

  def initialize url, site, type
    @url  = url
    @site = site
    @type = type
    @level = 0
    @failures = 0
  end

end
