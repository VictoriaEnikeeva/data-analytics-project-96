select * from ya_ads ya;
select * from vk_ads va;
select * from leads l;
select * from sessions s;

--Сценарий атрибуции
--Витрина для модели атрибуции Last Paid Click.
--Сортировка по полям amount — от большего к меньшему, null записи идут последними, 
--visit_date — от ранних к поздним,
--utm_source, utm_medium, utm_campaign — в алфавитном порядке.

with tab as (select l.visitor_id, visit_date, source as utm_source, row_number() over(partition by l.visitor_id order by s.visit_date  desc) as rn, medium as utm_medium, campaign as utm_campaign, lead_id, created_at, amount, closing_reason, status_id
from sessions s 
left join leads l on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
where medium in ('cpc','cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'))
select visitor_id, visit_date, utm_source, utm_medium, utm_campaign, lead_id, created_at, amount, closing_reason, status_id
from tab
where rn = '1'
order by amount desc nulls last, visit_date, utm_source, utm_medium, utm_campaign
limit 10

--Расчет расходов
--витрина со следующими полями: visit_date, utm_source / utm_medium / utm_campaign, visitors_count, total_cost,
--leads_count, purchases_count (closing_reason = “Успешно реализовано” или status_code = 142), revenue

with tab as 
(
select utm_source, utm_medium, utm_campaign, sum(daily_spent) as total_cost, to_char(campaign_date, 'YYYY-MM-DD') as campaign_date
from vk_ads va
where utm_medium <> 'organic'
group by utm_source, utm_medium, utm_campaign, campaign_date 
union all
select utm_source, utm_medium, utm_campaign, sum(daily_spent) as total_cost, to_char(campaign_date, 'YYYY-MM-DD') as campaign_date
from ya_ads ya
where utm_medium <> 'organic'
group by utm_source, utm_medium, utm_campaign, campaign_date 
),
tab3 as 
( 
select row_number() over(partition by s.visitor_id order by visit_date  desc) as rn,
to_char(visit_date, 'YYYY-MM-DD') as visit_date, lower(source) as utm_source, medium as utm_medium, campaign as utm_campaign, s.visitor_id,
lead_id, closing_reason, status_id, to_char(created_at, 'YYYY-MM-DD') as created_at, amount
from sessions s
left join leads l on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
where medium <> 'organic'
),
tab2 as 
(
select rn, visit_date, tab3.utm_source, tab3.utm_medium, tab3.utm_campaign, count(tab3.visitor_id) as visitors_count,
count(lead_id) as leads_count, total_cost,
count(case when closing_reason = 'Успешно реализовано' or status_id = '142' then 'one'end) as purchases_count,
sum(case when status_id = '142' then amount end) as revenue
from tab3
left join tab on tab3.utm_campaign = tab.utm_campaign and tab3.utm_medium = tab.utm_medium and tab3.utm_source = tab.utm_source
and tab3.visit_date = tab.campaign_date
where rn = '1'
group by rn, visit_date, tab3.utm_source, tab3.utm_medium, tab3.utm_campaign, total_cost)
select visit_date, tab2.utm_source, tab2.utm_medium, tab2.utm_campaign, visitors_count,
total_cost, leads_count,  purchases_count, revenue
from tab2 
order by revenue desc nulls last, visit_date, visitors_count desc, utm_source, utm_medium, utm_campaign







