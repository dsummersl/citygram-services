require 'spy_glass/registry'
require 'pry'

time_zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]

opts = {
  path: '/rtp-permits',
  cache: SpyGlass::Cache::Memory.new(expires_in: 300),
  source: 'https://opendata.socrata.com/resource/9wjv-w4fx.json?'+Rack::Utils.build_query({
    '$limit' => 1000,
    '$order' => 'statusdate DESC',
    '$where' => <<-WHERE.oneline
      statusdate >= '#{7.days.ago.iso8601}' AND
      originaladdress1 IS NOT NULL
    WHERE
  })
}

SpyGlass::Registry << SpyGlass::Client::Socrata.new(opts) do |collection|
  features = collection.map do |item|
    time = Time.iso8601(item['statusdate']).in_time_zone(time_zone)

    city = item['city']
    title =
      "#{Time.iso8601(item['statusdate']).strftime("%m/%d  %I:%M %p")} - A new permit has been updated to #{item['statuscurrent']} at #{item['originaladdress1']}."

    title << " The permit type is #{item['permittypemapped']}: #{item['description']}}."

    latlon = /\( (?<lat>[-0-9.]+) , (?<lon>[-0-9.]+) \)/.match(item['location_extra'])

    if not latlon
      next
    end

    {
      'id' => item['permitnum'],
      'type' => 'Feature',
      'geometry' => {
        'type' => 'Point',
        'coordinates' => [
          latlon[:lat].to_f,
          latlon[:lon].to_f
        ]
      },
      'properties' => item.merge('title' => title)
    }
  end

  {'type' => 'FeatureCollection', 'features' => features}
end

