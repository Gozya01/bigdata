CREATE TABLE UserBehavior (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING,
    ts TIMESTAMP(3), -- 事件时间字段
    WATERMARK FOR ts AS ts - INTERVAL '5' SECOND -- 定义 watermark 允许 5 秒延迟
) WITH (
    'connector' = 'kafka',
    'topic' = 'user_behavior',
    'properties.bootstrap.servers' = 'kafka1:9092',
    'format' = 'json', -- 数据格式为 JSON
    'scan.startup.mode' = 'earliest-offset'
);

CREATE TABLE hourly_buy_count (
    hour_of_day STRING,     -- 小时，例如 "08"
    buy_count BIGINT        -- 购买数量
) WITH (
    'connector' = 'elasticsearch-7',     -- 使用 Elasticsearch 7 的连接器
    'hosts' = 'http://es:9200',     -- 替换为实际的 Elasticsearch 地址
    'index' = 'hourly_buy_count',        -- 索引名称
    'format' = 'json'                    -- 写入的数据格式
);

INSERT INTO hourly_buy_count
SELECT
    DATE_FORMAT(ts, 'HH') AS hour_of_day, -- 提取小时
    COUNT(*) AS buy_count                         -- 统计购买量
FROM UserBehavior
WHERE behavior = 'buy'                            -- 仅统计购买行为
GROUP BY DATE_FORMAT(ts, 'HH'); 


CREATE TABLE user_behavior_count (
    behavior STRING,        -- 用户行为（如 buy, pv, cart 等）
    behavior_count BIGINT   -- 对应行为的统计数量
) WITH (
    'connector' = 'elasticsearch-7',
    'hosts' = 'http://es:9200',  -- 替换为你的 Elasticsearch 主机地址
    'index' = 'user_behavior_count',  -- 索引名称
    'format' = 'json'                 -- 数据写入格式
);

INSERT INTO user_behavior_count
SELECT
    behavior,                        -- 用户行为(buy, pv 等)
    COUNT(*) AS behavior_count        -- 对应行为的计数
FROM UserBehavior
GROUP BY behavior; 


CREATE TABLE category_dim (
    sub_category_id BIGINT,
    parent_category_name STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:mysql://mysql8:3306/flink',
    'table-name' = 'category',
    'driver' = 'com.mysql.cj.jdbc.Driver',  -- 使用 com.mysql.cj.jdbc.Driver，适应 MySQL 8.x
    'username' = 'root',
    'password' = '123456',
    'lookup.cache.max-rows' = '5000',
    'lookup.cache.ttl' = '10min'
);

CREATE TABLE top_category (
    category_name STRING,
    buy_cnt BIGINT
) WITH (
    'connector' = 'elasticsearch-7',
    'hosts' = 'http://es:9200',
    'index' = 'top_category',
    'document-id.key-delimiter' = '_',  -- 可选项，设置 document id 的分隔符
    'format' = 'json',
    'sink.bulk-flush.max-actions' = '2',  -- 配置批量刷新最大动作数
    'sink.bulk-flush.max-size' = '1MB',  -- 配置批量刷新最大大小（可选）
    'sink.bulk-flush.interval' = '1s',    -- 配置刷新间隔
    'sink.flush-on-checkpoint' = 'true'   -- 配置是否在每次 checkpoint 时刷新
);


CREATE VIEW rich_user_behavior AS
SELECT U.user_id, 
       U.item_id, 
       U.behavior, 
       C.parent_category_name AS category_name  
FROM UserBehavior AS U 
LEFT JOIN category_dim AS C   
ON U.category_id = C.sub_category_id;  

INSERT INTO top_category
SELECT 
    category_name AS category_name, 
    COUNT(*) AS buy_cnt  
FROM rich_user_behavior
WHERE behavior = 'buy'
GROUP BY category_name;


CREATE TABLE top_category_pv (
    category_name STRING,
    pv_cnt BIGINT
) WITH (
    'connector' = 'elasticsearch-7',
    'hosts' = 'http://es:9200',
    'index' = 'top_category_pv',
    'document-id.key-delimiter' = '_',  -- 可选项，设置 document id 的分隔符
    'format' = 'json',
    'sink.bulk-flush.max-actions' = '2',  -- 配置批量刷新最大动作数
    'sink.bulk-flush.max-size' = '1MB',  -- 配置批量刷新最大大小（可选）
    'sink.bulk-flush.interval' = '1s',    -- 配置刷新间隔
    'sink.flush-on-checkpoint' = 'true'   -- 配置是否在每次 checkpoint 时刷新
);


CREATE VIEW rich_user_behavior_pv AS
SELECT U.user_id, 
       U.item_id, 
       U.behavior, 
       C.parent_category_name AS category_name  
FROM UserBehavior AS U 
LEFT JOIN category_dim AS C   
ON U.category_id = C.sub_category_id;  

INSERT INTO top_category_pv
SELECT 
    category_name AS category_name, 
    COUNT(*) AS buy_cnt  
FROM rich_user_behavior_pv
WHERE behavior = 'pv'
GROUP BY category_name;