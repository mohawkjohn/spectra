require 'plotrb'
require 'yaml'
require 'pry'
require 'date'

HEIGHT=800
WIDTH=600

resources   = YAML.load(File.read('missions.yaml'))
minerals    = YAML.load(File.read('peaks.yaml'))

missions    = resources[:missions]
atmospheres = resources[:atmospheres]
has         = atmospheres.select { |k,v| v == true }.keys
hasnot      = atmospheres.select { |k,v| v == false }.keys

spectra     = Hash.new { |h,k| h[k] = [] }

def parse_date d
  if d.is_a?(Fixnum)
    Date.new(d)
  elsif d == "future"
    Date.new(2015)
  elsif d.include?(',')
    Date.parse(d.split(',')[0])
  else
    Date.parse(d)
  end
end

missions.each do |mission|
  unless mission.has_key?(:launch)
    STDERR.puts "Launch date missing for item #{mission.inspect}"
  end

  # Determine whether we're looking at a place with an atmosphere or not.
  #binding.pry
  unless mission[:destinations].nil?
    no_atmosphere = mission[:destinations] & hasnot
    next if no_atmosphere.empty?
  end

  #puts "mission #{mission.inspect}"
  mission[:sensors].each do |sensor|
    #puts "\tsensor #{sensor.inspect}"
    if sensor.has_key?(:spectra) && !sensor[:spectra].nil?
      sensor[:spectra].each do |spectrum|
        spectra[sensor[:abbrev] || sensor[:name]] << spectrum.merge({
          :mission => (mission[:abbrev] || mission[:name]),
          :launch  => parse_date(mission[:launch]),
          :width   => sensor[:width] || 1024
        })
      end
    else
      STDERR.puts "sensor #{sensor[:abbrev] || sensor[:name]} on #{mission[:abbrev] || mission[:name]} is missing spectra"
    end
  end
end

spectra.each_pair do |key,ary|
  ary.each.with_index do |item,i|
    extra = {
        :id => key,
      }

    if item.has_key?(:peak)
      extra[:mean] = item[:peak]

      # Make sure it has a low and a high
      if !item.has_key?(:low) && !item.has_key?(:high)
        unless item.has_key?(:resolution)
          raise("resolution missing for item #{item.inspect}")
        end
        extra[:low]  = item[:peak] - item[:resolution]/2.0
        extra[:high] = item[:peak] + item[:resolution]/2.0
      elsif item.has_key?(:low) && !item.has_key?(:high)
        extra[:high] = item[:low] + item[:resolution]
      elsif item.has_key?(:high) && !item.has_key?(:low)
        extra[:low] = item[:high] - item[:resolution]
      end
    elsif item.has_key?(:low)
      if item.has_key?(:high)
        extra[:mean] = (item[:low] + item[:high]) / 2.0
      else
        extra[:mean] = (2*item[:low] + item[:resolution]) / 2.0 # no high given
      end
    elsif item.has_key?(:high)
      extra[:mean] = (2*item[:high] - item[:resolution]) / 2.0 # no low given
    end

    spectra[key][i] = item.merge(extra)

    # Make sure we have a resolution for the heatmap
    spectra[key][i][:resolution] ||= spectra[key][i][:high] - spectra[key][i][:low]
  end
end

spectra = spectra.values.flatten.sort_by { |s| s[:launch] }
spectra.delete_if { |s| s[:low] > 5000 }

m = []
pos = 0
minerals.each do |key, s|
  s.each do |low_high|
    next if low_high[0] > 5000
    #low_high[1] = 5000 if low_high[1] > 5000
    m << { :id => key, :low => low_high[0], :high => low_high[1], :pos => pos }
    pos += 1
  end
end
minerals = m.sort_by { |x| x[:pos] }

sensor_data = pdata.name('spectra').values(spectra)
mineral_data = pdata.name('minerals').values(minerals)
#minima_data = pdata.name('minima').values(olivine)

#binding.pry

y1 = ordinal_scale.name('sensors').from('spectra.mission').range([0, HEIGHT*0.5])
y2 = ordinal_scale.name('absorbances').from('minerals.id').range([HEIGHT*0.5, HEIGHT]) #range([HEIGHT*2/3.0, HEIGHT])
xs = pow_scale.name('x').from('spectra.mean').exponent(0.4).domain([100,5000]).range([-100.0, WIDTH.to_f])
cs = log_scale.name('c').from('spectra.resolution').domain([0.1,1000.0]).range(['blue', 'red'])
rgbs = log_scale.name('rgb').from('spectra.peak').domain([426.3, 529.7, 552.4]).range(['red', 'green', 'blue'])
ws = log_scale.name('w').from('spectra.width').domain([1,5024]).range([1.0, HEIGHT*0.5 / spectra.map { |s| s[:mission] }.sort.uniq.size.to_f - 5.0])

rm = rect_mark.from(sensor_data) do
  enter do
    x_start  { scale(xs).from(:low) }
    x_end    { scale(xs).from(:high)}
    y_start  { scale(y1).from(:mission) }
    height   { scale(ws).from(:width) }
    fill     { scale(cs).from(:resolution) }
    fill_opacity 0.5
    #stroke   { scale(rgbs).from(:peak) }
  end
end

rm2 = rect_mark.from(mineral_data) do
  enter do
    x_start   { scale(xs).from(:low)  }
    x_end     { scale(xs).from(:high) }
    y_start   { scale(y2).from(:id) }
    height    { scale(y2).offset(-1).use_band }
    fill 'red'
    fill_opacity 0.5
  end
end

=begin
rm3 = rect_mark.from(minima_data) do
  enter do
    x_start   { scale(xs).from(:v) }
    x_end     { scale(xs).from(:v) }
    y_start   { scale(y2).from(:id) }
    height    { scale(y2).offset(-1).use_band }
    fill 'black'
    stroke 'black'
    fill_opacity 0.01
    stroke_opacity 0.01
  end
end
=end

tm = text_mark.from(sensor_data) do
  enter do
    x       { scale(xs).from(:mean)}
    text    { field(:id) }
    y       { scale(y1).from(:mission) }
    font_size 7
    angle 270
    align :right
    baseline :bottom
    fill '#000'
  end
end

l = legend do
  fill cs
  title "Sampling interval"
  offset 10

  properties do
    symbols do
      fill_opacity 0.6
    end

    #x WIDTH
  end
end

=begin
"legends": [
  {
    "fill": "c",
    "title": "Sampling interval",
    "offset": 10,
    "properties": {
      "symbols": {
        "fillOpacity": {"value": 0.5},
        "stroke": {"value": "transparent"}
      }
    }
  }
=end

#tm = text_mark.from(sensor_data) do
#  enter do
#    x { scale(xs).from(:low) }
#    y { scale(y1).field(:id).offset(-2) }
#    text { field(:id) }
#    align :center
#    baseline :bottom
#    fill '#000'
#  end
#end


vis = visualization.width(WIDTH).height(HEIGHT) do
  padding top: 10, left: 140, bottom: 30, right: 200
  data sensor_data, mineral_data #, minima_data
  scales xs, y1, y2, cs, rgbs, ws
  marks rm, rm2 #, rm3 #, tm
  legends l
  axes x_axis.scale(xs).values([100,300,600,900,1700,2500,5000]).with_grid.layer(:back), y_axis.scale(y1), y_axis.scale(y2) #,10000,25000,50000,100000,250000,500000,1000000]), y_axis.scale(y1)
end

puts vis.generate_spec(:pretty)

