module ContainersHelper



	def upgrade_suggestion

		if !current_user
			html='<h4>Up to 2 GB For Free</h4>'
		else
			if current_user.priviledge == "1"
				html='<h4>Up to 2 GB Per Transfer</h4>'
			elsif current_user.priviledge == "3"
				html='<h4>Up to 2 GB Per Transfer</h4>'
			elsif current_user.priviledge == "4"
				html='<h4>Up to 2 GB Per Transfer</h4>'
			elsif current_user.priviledge == "5"
				html='<h4>Up to 2 GB Per Transfer</h4>'
			end
		end

		return html.html_safe

	end



	def get_size(container)
		total=0
		for s in container.stuffs
			total=total+s.file_file_size
		end
		return number_to_human_size(total)
	end



	def expired(container)
		if container.state=="removed"
			return true
		else
			return false
		end
	end



	def expiration_day(container)
	  if current_user.priviledge!="1"
	  	return "Never"
	  else 		
		interval = Time.at(container.exptime-Time.zone.now).day

		if Time.at(container.exptime-Time.zone.now).to_i <= 0
			return "Expired"
		else
			return interval.to_s + " Days"
		end
	  end 

	end
		
	def need_pwd(container)


		if(!current_user)
			if((container.password.nil?)||(container.password.empty?))
				return false
			else
				return true
			end
		else
			if(container.user_id!=current_user.id)
				if((container.password.nil?)||(container.password.empty?))
					return false
				else
					return true
				end					
			else
				return false			
			end
		end

	end
		

end
