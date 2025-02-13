-- 1.创建视图方便后续查看分析
-- 创建产品销售视图
CREATE VIEW product_sales AS
SELECT 
    product_id,
    category,
    actual_price,
    discounted_price,
    discount_percentage,
    rating,
    rating_count,
    about_product,
    estimated_sales
FROM amazon_sql;

-- 创建评价分析视图
CREATE VIEW review_analysis AS
SELECT 
    product_id,
    category,
    rating,
    rating_count,
    sentiment,
    review_content,
		estimated_sales
FROM amazon_sql;

-- 2.产品销售分析
-- 产品销售分析：计算销售额、按类别/价格区间分组统计、找出销售额排名前N的产品等。
-- 按类别统计销售情况
SELECT 
    category,
    COUNT(*) as product_count,
    ROUND(AVG(actual_price), 2) as avg_price,
    ROUND(SUM(estimated_sales), 2) as total_sales,
    ROUND(AVG(rating), 2) as avg_rating
FROM product_sales
GROUP BY category
ORDER BY total_sales DESC;

-- 价格区间分析
WITH price_segments AS (
    SELECT
        CASE
            WHEN CAST(actual_price AS DECIMAL(10, 2)) <= 2000 THEN 'low'
            WHEN CAST(actual_price AS DECIMAL(10, 2)) <= 5000 THEN 'middle'
            ELSE 'high'
        END AS price_segment,
        product_id,
        category,
        actual_price,
        discounted_price,
        discount_percentage,
        rating,
        rating_count,
        about_product,
        estimated_sales
    FROM product_sales
)
SELECT
    price_segment,
    COUNT(*) AS product_count,
    ROUND(AVG(rating), 2) AS avg_rating,
    ROUND(SUM(estimated_sales), 2) AS total_sales
FROM price_segments
GROUP BY price_segment
ORDER BY total_sales DESC;

-- Top N 畅销产品
SELECT 
    product_id,
    category,
    actual_price,
    estimated_sales,
    rating,
    RANK() OVER (ORDER BY estimated_sales DESC) as sales_rank
FROM product_sales
WHERE rating >= 4.0
ORDER BY estimated_sales DESC
LIMIT 10;

-- 3.用户评价分布
-- 用户评价分析：计算平均评分、评价数量、按评分/情感倾向分组统计等。
-- 评分分布分析
SELECT 
    FLOOR(rating) as rating_range, /*向下取整，得到评分的整数部分*/
    COUNT(*) as product_count,
    ROUND(AVG(rating_count), 0) as avg_review_count,
    ROUND(AVG(estimated_sales), 2) as avg_sales
FROM review_analysis
GROUP BY FLOOR(rating)
ORDER BY rating_range;

-- 情感分析统计
SELECT 
    CASE 
        WHEN sentiment > 0 THEN 'positive'
        WHEN sentiment < 0 THEN 'negative'
        ELSE 'neutral'
    END as sentiment_category,
    COUNT(*) as review_count,
    ROUND(AVG(rating), 2) as avg_rating
FROM review_analysis
GROUP BY 
    CASE 
        WHEN sentiment > 0 THEN 'positive'
        WHEN sentiment < 0 THEN 'negative'
        ELSE 'neutral'
    END;
		
		
-- 4.折扣区间分析
WITH discount_segments AS (
    SELECT 
        CASE 
            WHEN discount_percentage <= 0.1 THEN 'low discount'
            WHEN discount_percentage <= 0.4 THEN 'middle discount'
            ELSE 'high discount'
        END as discount_segment,
            product_id,
						category,
						discount_percentage,
						rating,
						rating_count,
						estimated_sales
    FROM product_sales
)
SELECT 
    discount_segment,
    COUNT(*) as product_count,
    ROUND(AVG(estimated_sales), 2) as avg_sales,
    ROUND(AVG(rating), 2) as avg_rating
FROM discount_segments
GROUP BY discount_segment
ORDER BY avg_sales DESC;

-- 折扣转化效果
SELECT 
    category,
    ROUND(AVG(CASE 
        WHEN discount_percentage > 0 
        THEN estimated_sales 
        ELSE 0 
    END), 2) as avg_discounted_sales,
    ROUND(AVG(CASE 
        WHEN discount_percentage = 0 
        THEN estimated_sales 
        ELSE 0 
    END), 2) as avg_normal_sales
FROM product_sales
GROUP BY category
HAVING avg_discounted_sales > 0 AND avg_normal_sales > 0
ORDER BY (avg_discounted_sales - avg_normal_sales) DESC;


-- 创建储存过程并进行综合分析
DELIMITER //

CREATE PROCEDURE analyze_product_performance_by_category(
    IN category_name VARCHAR(100),
    IN min_rating DECIMAL(3,1)
)
BEGIN
    -- 类别整体表现
    SELECT 
        COUNT(*) as product_count,
        ROUND(AVG(rating), 2) as avg_rating,
        ROUND(AVG(estimated_sales), 2) as avg_sales,
        ROUND(AVG(discount_percentage), 2) as avg_discount
    FROM product_sales
    WHERE category = category_name
    AND rating >= min_rating;
    
    -- Top 5 产品
    SELECT 
        product_id,
        actual_price,
        rating,
        estimated_sales,
        discount_percentage
    FROM product_sales
    WHERE category = category_name
    AND rating >= min_rating
    ORDER BY estimated_sales DESC
    LIMIT 5;
END //

DELIMITER ;

-- 调用存储过程
CALL analyze_product_performance('Electronics|HomeTheater,TV&Video|Televisions|SmartTelevisions', 4.0);