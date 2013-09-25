require_relative 'lazy_foo_helper'
require_relative 'timer'
#ORIGINAL: http://lazyfoo.net/SDL_tutorials/lesson14/index.php
# Adapted for Ruby & SDL 2.0 as functional test by BadQuanta

require 'sdl2/application'
require 'sdl2/engine/block_engine'
require 'sdl2/ttf'

describe "LazyFoo.net: Lesson 15: Advanced Timers" do
  
  before do
    @app = Application.new(title: subject)
    @frame = 0
    @fps = Timer.new
    @update = Timer.new
    @update.start
    @fps.start
    
    @image = Image.load!(img_path('background.png'))
    
    @app.painter do |surface|
      surface.fill_rect(surface.rect, [0, 0, 0])
      @image.blit_out(surface)
      true      
    end
    
    @app.after_loop do 
      @frame += 1
      if @update.get_ticks() > 1000
        
        fps = @frame./(@fps.get_ticks()./(1000.0))
        @app.window.title = "Average Frames Per Second: #{fps}"
      end
    end
  end
  
  after do
    @app.quit
    
  end
  
  it "works" do
    @app.loop(1)
    pending "don't know how to test this"
  end
end