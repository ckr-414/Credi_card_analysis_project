
---1- write a query to print top 5 cities with highest spends and their percentage contribution of total credit card spends 
With highest_spends as (select city,sum(amount) as spend from cc_trans 
group by city
order by spend desc limit 5)
,total_amt as(select sum(amount) as ttl_amt from cc_trans)

select city,round(spend*1.0/ttl_amt*100,2) as percentage_contribution from highest_spends
inner join total_amt where 1=1;


--2- write a query to print highest spend month and amount spent in that month for each card type
with cte as (select card_type,extract(year from transaction_date) as yr,extract(month from transaction_date) as mth,sum(amount) as spend from cc_trans
group by card_type,extract(year from transaction_date),extract(month from transaction_date)
order by yr,mth,spend)

select * from (select *,rank() over (partition by card_type order by spend desc) as rn from cte) where rn=1

--3- write a query to print the transaction details(all columns from the table) for each card type when it reaches a cumulative of 1000000 total spends(We should have 4 rows in the o/p one for each card type
with cte as (
select *,sum(amount) over(partition by card_type order by transaction_date,transaction_id) as total_spend
from cc_trans

)
select * from (select *, rank() over(partition by card_type order by total_spend) as rn  
from cte where total_spend >= 1000000) a where rn=1;



--4- write a query to find city which had lowest percentage spend for gold card type
--with total_amt as(select sum(amount) as ttl_amt from cc_trans) 
with cte as (select city,card_type,round(sum(amount)*1/(select sum(case when card_type='Gold' then amount end) as ttl_amt from cc_trans) *100,2) as percentage from cc_trans
where card_type='Gold'
group by city,card_type)
select * from (select city,row_number() over (order by percentage asc) rwn from cte)
where rwn=1;


with cte as (
select top 1 city,card_type,sum(amount) as amount
,sum(case when card_type='Gold' then amount end) as gold_amount
from cc_trans
group by city,card_type)
select 
city,sum(gold_amount)*1.0/sum(amount) as gold_ratio
from cte
group by city
having count(gold_amount) > 0 and sum(gold_amount)>0
order by gold_ratio;

--5- write a query to print 3 columns:  city, highest_expense_type , lowest_expense_type (example format : Delhi , bills, Fuel)
With cte as (select city,exp_type,sum(amount) as expense from cc_trans
group by city,exp_type
order by city,expense asc)
,sal as(select * from (select * 
,row_number() over (partition by city order by expense desc) as drn
,row_number() over (partition by city order by expense asc) as arn from  cte
order by city) where drn=1 or arn=1)
select city,concat(city,',',listagg(exp_type,',')) from sal
group by city

--Alternate approach
with cte as (
select city,exp_type, sum(amount) as total_amount from cc_trans
group by city,exp_type)
select
city , max(case when rn_asc=1 then exp_type end) as lowest_exp_type
, min(case when rn_desc=1 then exp_type end) as highest_exp_type
from
(select *
,rank() over(partition by city order by total_amount desc) rn_desc
,rank() over(partition by city order by total_amount asc) rn_asc
from cte) A
group by city;




--6- write a query to find percentage contribution of spends by females for each expense type

with spend_eachtypeby_femal as(
select exp_type,sum(amount) as exp_ttl_amt from cc_trans
where gender='F'
group by exp_type),
totalamtbytype as (select exp_type,sum(amount) as ttlamt from cc_trans
group by exp_type)

select a.exp_type,round(a.exp_ttl_amt*1.0/ttlamt ,2) from spend_eachtypeby_femal a
inner join totalamtbytype b on b.exp_type=a.exp_type;

--alternate approach
select exp_type,
sum(case when gender='F' then amount else 0 end)*1.0/sum(amount) as percentage_female_contribution
from cc_trans
group by exp_type
order by percentage_female_contribution desc;



--7- which card and expense type combination saw highest month over month growth in Jan-2014

with mnthvicesales as (select card_type,exp_type,extract(year from transaction_Date) as yer,extract(month from transaction_Date) as mnth,sum(amount) as ttlamt from cc_trans
where extract(year from transaction_Date)=14
group by card_type,exp_type,extract(year from transaction_Date),extract(month from transaction_Date)
order by yer,mnth)
select *,ttlamt-prevamt from (
select *,lag(ttlamt,1) over (partition by card_type,exp_type order by yer,mnth) as prevamt from  mnthvicesales)
where prevamt is not null  and mnth=1


with cte as (
select card_type,exp_type,extract(year from transaction_Date) yt
,extract(month from transaction_Date) mt,sum(amount) as total_spend
from cc_trans
group by card_type,exp_type,extract(year from transaction_Date),extract(month from transaction_Date)
)
select  top 1 *, (total_spend-prev_mont_spend) as mom_growth
from (
select *
,lag(total_spend,1) over(partition by card_type,exp_type order by yt,mt) as prev_mont_spend
from cte) A
where prev_mont_spend is not null and yt=2014 and mt=1
order by mom_growth desc;




--9- during weekends which city has highest total spend to total no of transcations ratio 

select top 1 city , sum(amount)*1.0/count(1) as ratio
from cc_trans
where dayname(transaction_date) in ('Sun','Sat')
--where datename(weekday,transaction_date) in ('Saturday','Sunday')
group by city
order by ratio desc;
--select dayname(transaction_date),extract(weekday from transaction_date) from cc_trans

--10- which city took least number of days to reach its 500th transaction after the first transaction in that city

with cte as (
select *
,row_number() over(partition by city order by transaction_date,transaction_id) as rn
from cc_trans)
select top 1 city,datediff(day,min(transaction_date),max(transaction_date)) as datediff1
from cte
where rn=1 or rn=500
group by city
having count(1)=2
order by datediff1 