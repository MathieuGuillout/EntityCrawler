require 'digest/md5'
require "open-uri"
require 'rubygems'
require 'aws-sdk'
require 'timeout'
require_relative 'disk_queue'


def style_attribs style, entity_type
  Helper.ostructh(style[entity_type])[:attributes]
end


def download_file url, key, config
  open(url) do |f|
    File.open(File.join(config.temp_path, key), "wb") do |file|
      file.puts f.read
    end
  end
end

def upload_file key, config, config_property, s3_bucket
  s3_key  = config_property[:key_prefix] + key
  s3_file = s3_bucket.objects[s3_key]

  s3_file.write(Pathname.new(File.join(config.temp_path, key)))
end

def remove_file key, config
  File.delete(File.join(config.temp_path, key))
end

def process_file key, config, config_property
  filename  = File.join(config.temp_path, key)
  resized   = File.join(config.temp_path, key)

  size      ='%[fx: w<h ? h : w ]'
  offset_x  ='%[fx: w<h ? (w-h)/2 : 0 ]'
  offset_y  ='%[fx: w<h ? 0 : (h-w)/2 ]'
  viewport  = "#{size}x#{size}+#{offset_x}+#{offset_y}"

  command = "convert #{filename} "
  command += " -virtual-pixel edge "
  command += ' -set option:distort:viewport "' + viewport + '"  '
  command += " -distort SRT 0 "
  command += " -resize #{config_property[:size]} "
  command += " -quality 95 PJPEG:#{resized}"

  `#{command}`  
end


class CDN
  

  @@db = MongoClient.new("localhost", 27017, :pool_size => 10, :pool_timeout => 10).db("queue")
  @@queue = DBQueue.new("images", @@db)
  @@saving = false
  @@running = false

  def CDN.save style, entity_type, entities, config
    @@queue << { :style => style, :entity_type => entity_type, :entities => entities, :config => config }
    if not @@running
      CDN.run()
    end
  end

  def CDN.empty_queue
    while @@queue.size > 0
      j = @@queue.pop
      begin
        Timeout::timeout(1) {
          CDN.internal_save j[:style], j[:entity_type], j[:entities], j[:config]
        }
      rescue => ex
        @@queue << j if ex.class == AWS::S3::Errors::RequestTimeout or ex.class == Timeout::Error

        print "Exception : #{ex}\n" 
        ex.backtrace.each do |row|
          print row, "\n"
        end

      end
    end
  end

  def CDN.run()
    t = Thread.new do 
      while true do
        @@running = true
        CDN.empty_queue
        sleep 3
      end
    end
    t.join()
  end

  def CDN.internal_save style, entity_type, entities, config
  

    s3 = AWS::S3.new(
      :access_key_id => config.amazon.access_key_id, 
      :secret_access_key => config.amazon.secret_access_key
    )

    s3_bucket = s3.buckets[config.amazon.bucket]

    entities.each do |entity|

      style_attribs(style, entity_type).each do |k, v|

        if v.kind_of? Hash and v[:cdn]
          url = entity[k.to_s]
          if not url.nil?
            key = Digest::MD5.hexdigest(url)

            download_file url, key, config
            process_file  key, config, v[:cdn]
            upload_file   key, config, v[:cdn], s3_bucket
            remove_file   key, config
          end
        end

      end

    end
  end
   
  def CDN.has_a_job style, entity_type
    has_a_cdn_job = false
    style_attribs(style, entity_type).each do |k, v|
      has_a_cdn_job = true if v.kind_of? Hash and v[:cdn]
    end
    has_a_cdn_job
  end

end
