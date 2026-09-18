#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'

require 'json'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'date'

# Check for required environment variables
unless ENV['WHATSAPP_API_TOKEN'] && ENV['WHATSAPP_CHANNEL']
  warn "Error: WHATSAPP_API_TOKEN and WHATSAPP_CHANNEL environment variables must be set"
  exit 1
end
ENDPOINT = URI('https://gate.whapi.cloud/messages/text') # Whapi.Cloud "send text message" endpoint

# Load feeds from JSON file
def load_feeds
  JSON.parse(File.read('feeds.json'))
end

# Save feeds to JSON file
def save_feeds(feeds)
  File.write('feeds.json', JSON.pretty_generate(feeds))
end

# Fetch and parse an RSS feed
def fetch_feed(url)
  uri = URI(url)
  response = Net::HTTP.get_response(uri)

  unless response.is_a?(Net::HTTPSuccess)
    warn "Failed to fetch #{url}: #{response.code} #{response.message}"
    return nil
  end

  Nokogiri::XML(response.body)
rescue StandardError => e
  warn "Error fetching #{url}: #{e.message}"
  nil
end

# Extract items from a parsed RSS feed
def extract_items(doc, feed_name, seen_guids)
  return [] unless doc

  items = []

  # Handle both RSS 2.0 and Atom feeds
  doc.css('item, entry').each do |item_node|
    # Get guid/id
    guid = item_node.css('guid, id').text.strip
    next if guid.empty?
    next if seen_guids.include?(guid)

    # Get title
    title = item_node.css('title').text.strip

    # Get link
    link = item_node.css('link').text.strip
    # For Atom feeds, link might be in href attribute
    if link.empty? && item_node.css('link').first
      link = item_node.css('link').first['href'] || ''
    end

    # Get pubDate or published date
    pub_date_str = item_node.css('pubDate, published').text.strip
    pub_date = nil

    begin
      pub_date = DateTime.parse(pub_date_str) unless pub_date_str.empty?
    rescue ArgumentError
      # If parsing fails, skip this item or use a default date
      next
    end

    next unless pub_date

    items << {
      guid: guid,
      title: title,
      link: link,
      pub_date: pub_date,
      feed_name: feed_name
    }
  end

  items
rescue StandardError => e
  warn "Error extracting items from #{feed_name}: #{e.message}"
  []
end

# Send item to WhatsApp via Whapi.cloud API
def send_item_to_whatsapp(item)
  body = "*#{item[:title]}*\n#{item[:link]}"
  puts "Sending item to WhatsApp:\n#{body}"

  # Send the request to the Whapi.cloud API
  http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(ENDPOINT)
  request['Accept'] = 'application/json'
  request['Content-Type'] = 'application/json'
  request['Authorization'] = "Bearer #{ENV['WHATSAPP_API_TOKEN']}"

  request.body = JSON.generate({
    to: ENV['WHATSAPP_CHANNEL'],
    body: body
  })

  response = http.request(request)

  unless response.code.to_i >= 200 && response.code.to_i < 300
    warn "Error: Received HTTP #{response.code}"
    warn "Response body: #{response.body}"
    exit 1
  end

  puts "Success!"
end

# Main program
feeds = load_feeds

# Collect all items from all feeds
all_items = []

feeds.each do |feed|
  feed_name = feed['name']
  feed_url = feed['url']
  seen_guids = feed['seen'] || []

  doc = fetch_feed(feed_url)
  items = extract_items(doc, feed_name, seen_guids)
  all_items.concat(items)
end

# Find the oldest item
if all_items.empty?
  puts "No new items found."
  exit 0
end

oldest_item = all_items.min_by { |item| item[:pub_date] }

# Print the oldest item
send_item_to_whatsapp(oldest_item)

# Update feeds.json to mark this item as seen
feeds.each do |feed|
  if feed['name'] == oldest_item[:feed_name]
    feed['seen'] ||= []
    feed['seen'] << oldest_item[:guid] unless feed['seen'].include?(oldest_item[:guid])
  end
end

save_feeds(feeds)
