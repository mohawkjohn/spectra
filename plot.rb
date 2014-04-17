require 'plotrb'
require 'yaml'
require 'pry'

missions = YAML.load(File.read('missions.yaml'))[:missions]

spectra = {}

missions.each do |mission|
  puts "mission #{mission.inspect}"
  mission[:sensors].each do |sensor|
    puts "\tsensor #{sensor.inspect}"
    if sensor.has_key?(:spectra) && !sensor[:spectra].nil?
      sensor[:spectra].each do |spectrum|
        spectra[sensor[:abbrev] || sensor[:name]] = spectrum.merge({:mission => (mission[:abbrev] || mission[:name]) })
      end
    else
      puts "sensor is missing spectra"
    end
  end
end

spectra.each_pair do |key,value|
  spectra[key] = value.merge({:id => "#{value[:mission]}: #{key}"})
end

data = pdata.name('spectra').values(spectra.values)

ys = ordinal_scale.name('sensors').from('spectra.id').to_height
xs = linear_scale.name('x').from('spectra.peak').nicely.to_width

mark = rect_mark.from(data) do
  enter do
    x_start  { scale(xs).from(:low) }
    x_end    { scale(xs).from(:high)}
    y_start  { scale(ys).from(:id)  }
    height   { scale(ys).offset(-1).use_band }
  end
  update do
    fill 'steelblue'
  end
  hover do
    fill 'red'
  end
end

vis = visualization.width(600).height(600) do
  padding top: 10, left: 250, bottom: 30, right: 15
  data data
  scales xs, ys
  marks mark
  axes x_axis.scale(xs), y_axis.scale(ys)
end

puts vis.generate_spec(:pretty)

