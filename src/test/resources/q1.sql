-- -- 开启 mini-batch
-- SET table.exec.mini-batch.enabled=true;
-- -- mini-batch的时间间隔，即作业需要额外忍受的延迟
-- SET table.exec.mini-batch.allow-latency=1s;
-- -- 一个 mini-batch 中允许最多缓存的数据
-- SET table.exec.mini-batch.size=1000;
-- -- 开启 local-global 优化
-- SET table.optimizer.agg-phase-strategy=TWO_PHASE;
--
-- -- 开启 distinct agg 切分
-- SET table.optimizer.distinct-agg.split.enabled=true;


-- source
CREATE TABLE user_log (
    user_id VARCHAR,
    item_id VARCHAR,
    category_id VARCHAR,
    behavior VARCHAR,
    ts TIMESTAMP_LTZ(3),
    -- 声明 ts 是事件时间属性，并且用 延迟 5 秒的策略来生成 watermark
    WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'user_behavior',
    'scan.startup.mode' = 'earliest-offset',
    'properties.bootstrap.servers' = 'localhost:9092',
    'properties.group.id' = 'flink',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

-- sink
CREATE TABLE pvuv_sink (
    dt TIMESTAMP(3),
    pv BIGINT,
    uv BIGINT
) WITH (
    'connector.type' = 'jdbc',
    'connector.url' = 'jdbc:mysql://localhost:3306/flink-test',
    'connector.table' = 'pvuv_sink',
    'connector.username' = 'root',
    'connector.password' = '123456',
    'connector.write.flush.max-rows' = '1'
);


INSERT INTO pvuv_sink
SELECT
  tumble_start(ts, interval '1' minute) dt,
  COUNT(*) AS pv,
  COUNT(DISTINCT user_id) AS uv
FROM user_log
GROUP BY tumble(ts, interval '1' minute);