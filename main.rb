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
	has n, :transactions

	belongs_to :user

	before :save do
		self.last_transaction = Time.new
		self.number ||= gen_num(self.type)
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
	belongs_to :user

	def credit(balance, amount)
		balance + amount
	end

	def debit(balance, amount)
		balance - amount
	end
end

DataMapper.finalize
DataMapper.auto_upgrade!

configure do
	enable :sessions
end

get "/" do
	redirect to("/login")
end

post '/user/new' do
	user = User.create(params[:user])
	session[:name] = user.name
	session[:id] = user.id
	redirect to("/profile")
end

get '/login' do
	if session[:id] 
		redirect to("/profile")
	else
		@title = "Login"
		erb :login
	end
end

get '/user/logout' do
	session.clear
	redirect to("/login")
end

post '/user/login/process' do
	email = params[:email]
	password = params[:password]
	if	@user = User.first(email: email, password: password)
		session[:id] = @user[:id]
		session[:name] = @user[:name]
		redirect to("/profile")
	else
		redirect to("/login")
	end
end

get '/register' do
	@title = "Register"
	erb :register
end

get '/profile'  do
	@title = "My Profile"
	if session[:id] != nil
		@user = User.get(session[:id])
		@accounts = Account.all(user_id: session[:id])
		@transactions = Transaction.all(:account => { :user => @user })
		puts @transactions
		erb :profile
	else
		redirect to('/login')
	end
end

post '/account/new' do
	acc = Account.new
	acc.pin = params[:account]["pin"]
	acc.type = params[:account]["type"]
	acc.balance = params[:account]["balance"]
	@user = User.get(session[:id])
	acc.user = @user
	if acc.balance != 0
		acc.save
		trans = Transaction.new(amount: acc.balance, type: "Deposit", time: Time.new, account: acc, user: @user)
		trans.save
		session[:msg] = "Your account has been created"
	else
		acc.save
	end
	
	redirect to("/profile")	
end

get '/create' do
	@title = "Create Account"
	erb :create_account
end

get '/deposit' do
	@title = "Make Deposit"
	@accounts = Account.all(user_id: session[:id])
	erb :deposit
end

post '/account/credit' do
	deposit = Transaction.new
	deposit.time = Time.new
	deposit.type = params[:deposit]["type"]
	account_id = params[:deposit]["account"]
	account_id = account_id.to_i
	deposit.amount = params[:deposit]["amount"]
	account = Account.get(account_id)
	deposit.account = account
	deposit.user = User.get(session[:id])
	account.update(balance: account.balance+deposit.amount, last_transaction: deposit.time)
	deposit.save
	session[:msg] = "Your transaction was successfu! Your new balance is #{deposit.account.balance}"
	redirect to("/profile")
end

get '/withdraw' do
	@title = "Make Withdrawal"
	@accounts = Account.all(user_id: session[:id])
	erb :withdrawal
end

post '/account/debit' do
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
		trans.user = User.get(session[:id])
		amount = trans.amount
		amount = amount.to_i
		balance = @account.balance
		balance = balance.to_i
		if balance <= amount
		session[:msg] = "You do not have sufficient balance to perform transaction."
			redirect to('/withdraw')
		elsif @account.update(balance: @account.balance-trans.amount, last_transaction: trans.time)
			trans.save
			session[:msg] = "Your have successfully withdrawn #{trans.amount} from your account. your new balance is #{account.balance}"
		else
			session[:msg] = "Unable to perform transaction. Try Again"
			redirect to('/withdraw')
		end
	else
		session[:msg] = "Incorrect Details. Try Again"
		redirect to('/withdraw')
	end
	redirect to('/profile')
end