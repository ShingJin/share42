require 'zip/zip'
require 'zip/zipfilesystem'
require 'resque_scheduler'
require 'aws/s3'
require 'drb'

class ContainersController < ApplicationController

  helper_method :sort_column, :sort_direction

  def download_all
    #log downloader's ip for security purposes
    ip = request.remote_ip.to_s 
    Spacecop.log_download(ip, params[:id].to_s, "zip")

    #connect to s3 bucket    
    options[:s3_config_filename] ||= "#{Rails.root}/config/amazon_s3.yml"
    config = YAML.load_file(options[:s3_config_filename])
    access_key_id = config['development']['access_key_id']
    secret_access_key = config['development']['secret_access_key']
    s3 = AWS::S3.new(
      :access_key_id => access_key_id,
      :secret_access_key => secret_access_key
    )
    bucket = s3.buckets['filetunnel']  

    #get the s3 object
    @container = Container.find_by_id_or_sha1(params[:id]) 
    zip_name = @container.stuffs.first.file_file_name.to_s + ".zip"        
    file_name = "zip/#{@container.sha1}/#{zip_name}"
    s3obj = bucket.objects[file_name]
    
    #update container's information
    @container.downloaded = @container.downloaded + 1
    @container.updated_at = Time.zone.now
    @container.save

    #create a list of files
    file_list = []        
    for stuff in @container.stuffs 
      file_list.push(stuff.file_file_name)
    end

    #send out an email
    email = params[:email]
    if (!email.nil?) 
      query = url_unescape(email)
      @email = @container.emails.where("name =?",query).first
      if(!@email.nil?)
        #keep track of number of downloads from one email
        @email.downloads = @email.downloads + 1
        @email.save
        @link = "https://share42.herokuapp.com/" + @container.sha1
        #notify the owner of the file
        if @email.downloads == 1
          if @container.user_id.nil?
            Notifier.download_notify(@email.name, @container.sender, @link, @filelist).deliver
          else
            @user=User.find(@container.user_id)
            if (@user.everytime == true||(@user.everytime == false && @email.downloads == 1))                  
              Notifier.download_notify(@email.name, @user.email, @link, @filelist).deliver
            end
          end
        end    
      end
    end   

    #generate url
    url = s3obj.url_for(:read,:expires => 10*60)
    (1..5).each do |try|
      begin
        redirect_to url.to_s
      rescue Exception => e
        sleep 1
      end
    end
  end

  def remove
    @container=Container.find_by_id_or_sha1(params[:id])   
    @user=User.find(current_user.id)

    #change user's avaiable storage space
    for stuff in @container.stuffs
      @user.storage = @user.storage-stuff.file_file_size
      stuff.destroy
    end
    @user.save
    @container.exptime = Time.zone.now
    @container.state = "removed"
    @container.save

    if (@container.is_single != true)&&(@container.zipped == true)
      #destroy zip
      options[:s3_config_filename] ||= "#{Rails.root}/config/amazon_s3.yml"
      config = YAML.load_file(options[:s3_config_filename])
      access_key_id = config['development']['access_key_id']
      secret_access_key = config['development']['secret_access_key']
      s3 = AWS::S3.new(
        :access_key_id => access_key_id,
        :secret_access_key => secret_access_key
      )
      bucket = s3.buckets['filetunnel']  
      zip_name = @container.stuffs.first.file_file_name.to_s + ".zip"
      file_name="zip/#{@container.sha1}/#{zip_name}"
      s3obj = bucket.objects[file_name]
      s3obj.delete()
    end
    if (@container.is_single != true)&&(@container.zipped == false)
      Spacecop.add_clean_later(@container.sha1)
    end
    redirect_to :action => 'index'
  end

  #remove folder along with all the files
  def remove_folder
    @container = Container.find_by_id_or_sha1(params[:id])
    @container.destroy
    redirect_to :action => 'index'
  end

  def update
    @container = Container.find_by_id_or_sha1(params[:id])   
    @container.update_attributes(params[:container])
    @container.password = params[:container_password]
    if @container.save
      respond_to do |format|
        @message = "We have updated your settings for this folder"
        @type = "notice"
        format.js{
          render :action => "notice"
        }
      end 
    else
      @message = "Hmm, something went wrong"
      @type = "error"
      format.js{
        render :action => "notice"
      }
    end    
  end

  def show
    #@container=Container.find(Tiny::untiny(params[:id]))
    @container = Container.find_by_id_or_sha1(params[:id])   
    @files = @container.stuffs
    @url = request.url
    @link = Container.shorten(@url).short_url
    respond_to do |format|
      format.html
    end
  end

  def partial_update
    if current_user
      @containers = current_user.containers.where("empty =?", false).find(:all, :order=>'created_at desc', :limit => 6)
      respond_to do |format|      
        format.html {render :partial => "recentcontainer", :layout => false, :locals => {:containers => @containers} }  
      end  
    else
     respond_to do |format|      
        format.all{render :nothing => true, :status => 200, :content_type => 'text/html'}
      end 
    end
  end

  def new_transfer
    @container = current_user.containers.new  
    @containers = current_user.containers.where("empty =?",false).find(:all, :order=>'created_at desc',:limit => 6)
    sha1 = Digest::SHA1.hexdigest([@container.id.to_s,rand].join)
    @container.sha1 = sha1.to_s
    @container.save
    @stuff = @container.stuffs.new    
    #remember to clean the unused Container here   
    #need to change the url later
    @tiny_id = "https://share42.herokuapp.com/" + sha1
    @link = Container.shorten(@tiny_id).short_url
  end

  def new    
    @user = User.new        
    if(!current_user)
      @container = Container.new    
      #remember to clean the unused Container here   
      sha1 = Digest::SHA1.hexdigest([@container.id.to_s,rand].join)
      @container.sha1 = sha1.to_s
      @container.save
      @stuff = @container.stuffs.new    
      @tiny_id = "https://share42.herokuapp.com/" + sha1
      @link = Container.shorten(@tiny_id).short_url
    else
      redirect_to :action => 'index'
    end    
  end

  def fake_new(file)
      @container = Container.new    
      sha1 = Digest::SHA1.hexdigest([@container.id.to_s,rand].join)
      @container.sha1 = sha1.to_s
      @container.name = file[:name]
      @container.fake = true
      @container.save
      @stuff = @container.stuffs.new
      @stuff.file_file_name = file[:name]    
      @stuff.file_file_size = file[:size]
      @stuff.fake_link = file[:link]
      @stuff.save
  end

  def show_newtransfer
    if(!current_user)
      @container = Container.new    
      sha1=Digest::SHA1.hexdigest([@container.id.to_s,rand].join)
      @container.sha1=sha1.to_s
      @container.downloadcap=30
      @container.save
      @stuff = @container.stuffs.new    
      @tiny_id = "http://share42.herokuapp.com/containers/"+sha1
      @link=Container.shorten(@tiny_id).short_url
    else
      @container = current_user.containers.new  
      sha1=Digest::SHA1.hexdigest([@container.id.to_s,rand].join)
      @container.sha1=sha1.to_s
      @container.downloadcap=current_user.downloadcap
      @container.save
      @stuff = @container.stuffs.new    
      #remember to clean the unused Container here   
      #need to change the url later
      @tiny_id = "http://share42.herokuapp.com/containers/"+sha1
      @link=Container.shorten(@tiny_id).short_url
    end
    respond_to do |format|      
       format.html {render :partial=>"show_newtransfer",:layout => "layouts/application", :locals=>{:container=>@container,:stuff=>@stuff,:link=>@link} }
       format.js  
    end
  end

  def send_notification
    @container = Container.find_by_id_or_sha1(params[:id])
    stuff_list=[]
    @container.stuffs.each do |s|
      stuff_list<<s.id    
    end   
    if stuff_list.count!=1
      Resque.enqueue(Compression,@container.sha1,stuff_list,@container.stuffs.first.file_file_name)
    else
      @container.is_single=true
      @container.save
    end
    emails=@container.emails
    name_list=[]
    for c in @container.stuffs
      name_list<<c.file_file_name
    end
    link="http://share42.herokuapp.com/containers/#{@container.sha1}"
    #send out emails to recipients
    for e in @container.emails
          Notifier.notify(@container.subject,@container.message,@container.sender,e.name,name_list,link).deliver
    end
    #send out a confirmation email
    if @container.sender
          Notifier.confirm(@container.sender,@container.emails,name_list,link).deliver
    end
    respond_to do |format|      
          format.all{render :nothing => true, :status => 200, :content_type => 'text/html'}
    end 
  end

  def index
    sort=params[:sort]
    filter =  params[:filter]
    search = params[:search]
    state = $redis.get("user_"+current_user.id.to_s)
    if filter=="search"
      @relevant_items=[]
      for c in current_user.containers.where("empty =?",false).where("state !=?","removed")
        temp_item = c
        file_names = []
        for f in c.stuffs
          if f.file_file_name.downcase.include?(search.downcase)
            file_names << f.file_file_name
          end
        end
        temp_item[:files]=file_names
        if !(file_names.empty?)
          @relevant_items << temp_item
        end
      end
    end

    @sent_items = current_user.containers.where("empty =?",false).order(sort_column+" "+sort_direction).where("state !=?","removed")
    @removed_items = current_user.containers.where("empty =?",false).order(sort_column+" "+sort_direction).where("state =?","removed") 
    @personal_items = current_user.containers.where("empty =?",false).order(sort_column+" "+sort_direction).where("state =?","personal") 

    if filter.nil?
      if state == "removed"
        if sort.nil?
          @containers = @sent_items
        else
          @containers = @removed_items
        end
      elsif state == "normal"
        @containers = @sent_items 
      elsif state == "personal"
        @containers = @personal_items 
      elsif state == "search" 
        $redis.set("user_"+current_user.id.to_s,"normal")        
        @containers = @sent_items    
      end

    elsif filter == "normal"
      @containers = @sent_items
      $redis.set("user_"+current_user.id.to_s,"normal")
    elsif filter == "removed"
      @containers = @removed_items
      $redis.set("user_"+current_user.id.to_s,"removed")
    elsif filter == "personal"
      @containers = @personal_items
      $redis.set("user_"+current_user.id.to_s,"personal") 
    elsif filter == "search"  
      @containers = @relevant_items
      $redis.set("user_"+current_user.id.to_s,"search")             
    end

    @state = $redis.get("user_"+current_user.id.to_s)

    if sort=="exptime"
        @sort_by_name="Expiration date"
    elsif sort=="name"
        @sort_by_name="Name"
    elsif sort=="downloaded"
        @sort_by_name="Downloads"
    elsif sort=="total_size"
        @sort_by_name="Size"
    elsif sort=="created_at"  
        @sort_by_name="Created"
    else
        @sort_by_name="Created"
    end

    respond_to do |format|
      format.html
      format.js{render :action=>"update_index"}
    end
  end

  def show_container
    @container=Container.find_by_id_or_sha1(params[:id])   
    @link=Container.shorten("http://share42.herokuapp.com/containers/"+@container.sha1).short_url
    if(params[:password]==@container.password)      
      respond_to do |format|      
        format.html {render :partial => "container_main_visit",:locals =>{:container=>@container,:files=>@container.stuffs,:link=>@link} }  
        format.js  
      end
    else
      respond_to do |format|      
        format.html 
        format.js 
      end
    end  
  end

  module Compression
      @queue = :compression_queue
      def self.perform(container_id,stuff_list,file_file_name)       
        #outsourcing work to India lol!
        DRb.start_service()
        obj = DRbObject.new(nil,"druby://ec2-107-21-77-151.compute-1.amazonaws.com:9000")        
        if obj.compress(container_id,stuff_list,file_file_name)
          @container=Container.find_by_id_or_sha1(container_id)
          @container.zipped=true
          @container.save
        end
      end
  end

private

  def sort_column
    Container.column_names.include?(params[:sort]) ? params[:sort] : "created_at"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ?  params[:direction] : "desc"
  end

end
