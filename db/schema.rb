# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120410013821) do

  create_table "containers", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "tempuser_id"
    t.integer  "user_id"
    t.string   "password"
    t.boolean  "empty",       :default => true
    t.integer  "downloaded",  :default => 30
    t.string   "sha1"
    t.datetime "exptime"
    t.string   "name"
    t.boolean  "notif",       :default => true
    t.string   "sender"
    t.string   "subject"
    t.text     "message"
    t.boolean  "zipped",      :default => false
    t.integer  "total_size",  :default => 0
    t.boolean  "compressed"
    t.integer  "downloadcap"
    t.string   "state"
    t.boolean  "is_single"
    t.boolean  "fake"
  end

  create_table "emails", :force => true do |t|
    t.integer  "container_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.integer  "downloaded",   :default => 0
    t.integer  "downloads",    :default => 0
  end

  create_table "spacecops", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "stuffs", :force => true do |t|
    t.string   "name"
    t.integer  "container_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "file_file_name"
    t.string   "file_content_type"
    t.integer  "file_file_size"
    t.datetime "file_updated_at"
    t.integer  "downloads"
    t.string   "sha1"
    t.boolean  "notif",             :default => true
    t.boolean  "legal",             :default => false
    t.string   "uploader_ip"
    t.string   "fake_link"
  end

  create_table "tempusers", :force => true do |t|
    t.string   "ip"
    t.integer  "storage"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "capacity"
    t.integer  "priviledge"
    t.integer  "spf"
    t.integer  "downloadcap"
  end

  create_table "users", :force => true do |t|
    t.string   "email"
    t.string   "passowrd_hash"
    t.string   "password_salt"
    t.string   "priviledge"
    t.integer  "storage"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "capacity"
    t.integer  "spf"
    t.integer  "downloadcap"
    t.text     "list"
    t.boolean  "everytime",              :default => false
    t.boolean  "limitnotif",             :default => true
    t.string   "customer_id"
    t.string   "auth_token"
    t.string   "password_rest_token"
    t.datetime "password_reset_sent_at"
    t.string   "password_reset_token"
    t.string   "confirmation_code"
    t.boolean  "confirmed"
    t.datetime "confirmation_sent_at"
  end

end
