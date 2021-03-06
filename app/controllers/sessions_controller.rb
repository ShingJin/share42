class SessionsController < ApplicationController
    
    def new           
    end



    def create
      user = User.authenticate(params[:email], params[:password])
      if user 
        if user.confirmed == true
          $redis.set("user_"+user.id.to_s,"normal")
          if params[:remember_me]
            cookies.permanent[:auth_token] = user.auth_token
          else
            cookies[:auth_token] = user.auth_token
          end

          redirect_to '/new_transfer', :notice => "Welcome"
        else
          flash.now[:error] = "Please confirm your email address to access your account."
          render "new"
        end
      else
         flash.now[:error] = "Invalid email/password combination."
         render "new"
      end
    end



    def destroy
      cookies.delete(:auth_token)
      redirect_to root_url, :notice => "Logged out!"
    end


end
