require 'rubygems'
require 'sinatra'
require 'data_mapper'

DataMapper.setup(:default, "mysql://localhost/bankingApp")

class User
	include DataMapper::Resource
	property :id, Serial
	property :name, String
	property :email, String
	property :phone, String
	property :address, Text
	property :password, String
	property :registered_on, Date

	has n, :accounts

	def registered_on=date
		super Date.strptime(date, '%m/%d/%Y')
	end
end

class Account
	include DataMapper::Resource
	property :id, Serial
	property :pin, Integer
	property :type, String
	property :number, Integer
	property :balance, Float
	property :last_transaction, Date

	belongs_to :user

	before :save do
		self.last_transaction = Time.new
		self.number = gen_num(self.type)
	end

	def gen_num(type)
		case type
		when "Savings" then "41" << rand(9999).to_s.rjust(4,'0')
		when "Investment" then "42" << rand(9999).to_s.rjust(4,'0')
		when "Checking" then "43" << rand(9999).to_s.rjust(4,'0')
		end
	end

	def format(num)
    num = num.to_s.split(".")
    num[1] = num[1][0..1]
    num[0] = num[0].reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse!
    num.join(".")
end
end

class Transaction
	include DataMapper::Resource
	property :id, Serial
	property :amount, Float
	property :time, String
	property :type, String
	belongs_to :account
end

DataMapper.finalize
DataMapper.auto_upgrade!

configure do
	enable :sessions
end

post '/user' do
	user = User.create(params[:user])
	session[:name] = user.name
	session[:id] = user.id
	redirect to("/account")
end

get '/login' do
	@title = "Login"
	erb :login
end

get '/logout' do
	session.clear
	redirect to("/login")
end

post '/process' do
	email = params[:email]
	password = params[:password]
	if	@user = User.first(email: email, password: password)
		session[:id] = @user[:id]
		session[:name] = @user[:name]
		redirect to("/account")
	else
		redirect to("/login")
	end
end

get '/register' do
	@title = "Register"
	erb :register
end

get '/account'  do
	@title = "My Account"
	@user = User.get(session[:id])
	@accounts = Account.all(user_id: session[:id])
	erb :account
end

post '/create_account' do
	acc = Account.new
	acc.pin = params[:account]["pin"]
	acc.type = params[:account]["type"]
	#acc.number = acc.get_number(acc.type)
	acc.balance = params[:account]["balance"]
	#acc.last_transaction = params[:account]["last_transaction"]
	@user = User.get(session[:id])
	acc.user = @user
	acc.save
	puts @acc
	redirect to("/account")	
end

get '/createAccount' do
	@title = "Create Account"
	erb :create_account
end

get '/deposit' do
	@title = "Make Deposit"
	@accounts = Account.all(user_id: session[:id])
	erb :deposit
end

post '/make_deposit' do
	deposit = Transaction.new
	deposit.time = Time.new
	deposit.type = params[:deposit]["type"]
	account_id = params[:deposit]["account"]
	account_id = account_id.to_i
	deposit.amount = params[:deposit]["amount"]
	account = Account.get(account_id)
	deposit.account = account
	account.update(balance: account.balance+deposit.amount, last_transaction: deposit.time)
	deposit.save
	redirect to("/account")
end

get '/withdraw' do
	@title = "Make Withdrawal"
	@accounts = Account.all(user_id: session[:id])
	erb :withdrawal
end

post '/make_withdrawal' do
	account_id = params[:withdrawal]["account"]
	@account = Account.get(account_id)
	pin = params[:withdrawal]["pin"]
	pin = pin.to_i
	if @account.pin == pin 
		trans = Transaction.new
		trans.amount = params[:withdrawal]["amount"]
		trans.type = params[:withdrawal]["type"]
		trans.account = @account
		trans.time = Time.new
		amount = trans.amount
		amount = amount.to_i
		balance = @account.balance
		balance = balance.to_i
		if balance <= amount
			puts "You do not have sufficient balance to perform transaction."
			redirect to('/withdraw')
		elsif @account.update(balance: @account.balance-trans.amount, last_transaction: trans.time)
			trans.save
		else
			puts "Unable to perform transaction. Try Again"
			redirect to('/withdraw')
		end
	else
		puts "Incorrect Details. Try Again"
		redirect to('/withdraw')
	end
	redirect to('/account')
end