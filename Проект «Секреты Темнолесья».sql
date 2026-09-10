-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
		COUNT(*) AS count_users, -- Общее количество игроков, зарегистрированных в игре
		SUM(u.payer) AS count_payer, -- Количество платящих игроков
		ROUND(AVG(u.payer)::NUMERIC, 3) AS share_payer -- Доля платящих игроков от общего количества пользователей, зарегистрированных в игре
FROM fantasy.users AS u;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 	
		r.race, -- Раса персонажа
		SUM(u.payer) AS count_payer_race, -- Количество платящих игроков этой расы
		COUNT(*) AS count_race, -- Общее количество зарегистрированных игроков этой расы
		ROUND(AVG(u.payer)::NUMERIC, 3) AS share_payer_race -- Доля платящих игроков среди всех зарегистрированных игроков этой расы
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race
ORDER BY share_payer_race DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT 	
		COUNT(amount) AS total_purchases, -- Общее количество покупок
		SUM(amount) AS sum_cost_purchases, -- Суммарная стоимость всех покупок
		MIN(amount) AS min_cost_purchases, -- Минимальная стоимость покупки
		MAX(amount) AS max_cost_purchases, -- Максимальная стоимость покупки
		ROUND(AVG(amount)::NUMERIC, 2) AS avg_cost_purchases, -- Среднее значение стоимости покупки
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_cost_purchases, -- Медиану стоимости покупки
		ROUND(STDDEV(amount)::NUMERIC, 2) AS std_cost_purchases -- Стандартное отклонение стоимости покупки
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT 
		SUM(CASE 
				WHEN amount = 0
				THEN 1
				ELSE 0
	   END) AS null_purchases,  -- Количество нулевых покупок
-- Доля от нулевых покупок от общего числа покупок
	   ROUND(SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END)::NUMERIC / COUNT(amount), 3) AS share_zero_purchases
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:
WITH 
popular_epic AS (
	SELECT 	
			i.game_items AS item_name,
			COUNT(e.id) AS total_sales,
			COUNT(DISTINCT e.id) unique_users
	FROM fantasy.items AS i
	JOIN fantasy.events AS e USING(item_code)
	WHERE e.amount > 0
	GROUP BY item_name
)
SELECT	
		pe.item_name, 
		pe.total_sales, -- Общее количество внутриигровых продаж
		-- Доля продажи каждого предмета от всех продаж
		ROUND(pe.total_sales / SUM(pe.total_sales) OVER(), 3) AS share_item_relative,
		-- Доля игроков, которые хотя бы раз покупали этот предмет, от общего числа внутриигровых покупателей
		ROUND(pe.unique_users::NUMERIC / (SELECT COUNT(DISTINCT e.id) FROM fantasy.events e WHERE e.amount > 0), 3) AS share_users
FROM popular_epic AS pe
ORDER BY total_sales DESC;


-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH
-- СТЕ для подсчета общего количества зарегистрированных игроков для каждой расы
total_users AS (
	SELECT 	
			r.race_id,
			r.race,
			COUNT(u.id) AS count_users
	FROM fantasy.race AS r
	LEFT JOIN fantasy.users AS u USING(race_id)
	GROUP BY r.race_id, r.race
),
-- СТЕ для подсчета количества игроков, которые совершили внутриигровую покупку
total_byers AS (
	SELECT 	
			r.race_id,
			r.race,
			COUNT(DISTINCT e.id) AS count_byers
	FROM fantasy.race AS r
	LEFT JOIN fantasy.users AS u USING(race_id)
	LEFT JOIN fantasy.events AS e USING(id)
	WHERE e.amount > 0
	GROUP BY r.race_id, r.race
),
-- СТЕ для подсчета количества платящих игроков
total_payers AS (
	SELECT 	
			r.race_id,
			r.race,
			COUNT(DISTINCT e.id) AS count_payers
	FROM fantasy.race AS r
	LEFT JOIN fantasy.users AS u USING(race_id)
	LEFT JOIN fantasy.events AS e USING(id)
	WHERE e.amount > 0 AND u.payer = 1
	GROUP BY r.race_id, r.race
),
-- Информация об активности игроков, совершивших внутриигровую покупку, с учётом расы персонажа
stat AS (
	SELECT 	
			r.race_id,
			r.race,
			-- Среднее количество покупок на одного игрока
			ROUND(COUNT(e.transaction_id)/COUNT(DISTINCT e.id)::NUMERIC) AS avg_transactions_per_user,
			-- Средняя стоимость одной покупки
	   		ROUND(SUM(e.amount)::NUMERIC/COUNT(e.transaction_id)) AS avg_one_purchace_amount,
	   		-- Средняя суммарную стоимость всех покупок на одного игрока
	   		ROUND(SUM(e.amount)::NUMERIC/COUNT(DISTINCT e.id)) AS avg_all_purchaces_amount
	FROM fantasy.race AS r
	LEFT JOIN fantasy.users AS u USING(race_id)
	LEFT JOIN fantasy.events AS e USING(id)
	WHERE e.amount > 0
	GROUP BY r.race_id, r.race 
)
-- Основной запрос
SELECT 	
		tu.race_id,
		tu.race,
		count_users,
		count_byers,
		count_payers,
		-- Доля игроков, которые совершили внутриигровую покупку
		ROUND(count_byers/count_users::NUMERIC, 3) AS buyers_share,
		-- Доля платящих игроков
	   	ROUND(count_payers::NUMERIC/count_byers, 3) AS payers_share,
		avg_transactions_per_user,
		avg_one_purchace_amount,
		avg_all_purchaces_amount
FROM total_users AS tu
FULL JOIN total_byers AS tb USING (race_id)
FULL JOIN total_payers AS tp USING (race_id)
FULL JOIN stat AS s USING (race_id)
ORDER BY buyers_share DESC, payers_share DESC;
