import sys
import time
import json
import queue
from kafka import KafkaProducer
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone, timedelta

time.sleep(10)
servers = ['kafka1:9092']
topic = 'user_behavior'
path = '/app/UserBehavior.csv'

producer = KafkaProducer(bootstrap_servers=servers, 
                         value_serializer=lambda m: json.dumps(m).encode('utf-8'),
                        )

print("Producer started")

def convert_to_china_time(timestamp):
    # 转换为UTC时间
    utc_time = datetime.fromtimestamp(int(timestamp), tz=timezone.utc)
    
    # 中国时区 (UTC+8)
    china_time = utc_time + timedelta(hours=8)
    
    return china_time.strftime("%Y-%m-%d %H:%M:%S")

def send(line):
    cols = line.strip('\n').split(',')
    # 修改时间格式为 yyyy-MM-dd HH:mm:ss
    ts = convert_to_china_time(cols[4])
    if cols[0]==None or cols[1]==None or cols[2]==None or cols[3]==None or ts==None:
        return
    value = {"user_id": cols[0], "item_id": cols[1], "category_id": cols[2], "behavior": cols[3], "ts": ts}
    try:
        print(f"Sending message: {value}")
        # 发送消息，异步发送，无需阻塞等待
        producer.send(topic=topic, value=value).get(timeout=1)
        print("Message sent successfully")
    except Exception as e:
        print(f"Failed to send message: {e}")

if __name__ == "__main__":
    num = 1000

    if len(sys.argv) > 1:
        num = int(sys.argv[1])

    class BoundThreadPoolExecutor(ThreadPoolExecutor):
        def __init__(self, *args, **kwargs):
            super(BoundThreadPoolExecutor, self).__init__(*args, **kwargs)
            self._work_queue = queue.Queue(num * 2)

    with open(path, 'r', encoding='utf-8') as f:
        pool = BoundThreadPoolExecutor(max_workers=num)
        # 提交任务到线程池，线程池会异步执行
        for arg in f:
            pool.submit(send, arg)
        pool.shutdown(wait=True)