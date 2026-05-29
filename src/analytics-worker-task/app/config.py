import os


class Settings:
    # MongoDB
    MONGODB_URL: str = os.getenv("MONGODB_URL", "mongodb://root:secret@mongo-svc:27017")
    DATABASE_NAME: str = os.getenv("DATABASE_NAME", "analytics")

    # Kafka (task events only)
    KAFKA_BOOTSTRAP_SERVERS: str = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka-svc:9092")
    KAFKA_GROUP_ID: str = os.getenv("KAFKA_GROUP_ID", "analytics-worker-task")
    KAFKA_TOPIC_TASK: str = os.getenv("KAFKA_TOPIC_TASK", "task-events")

    # Worker metadata
    WORKER_NAME: str = "Analytics Task Worker"
    VERSION: str = "1.0.0"
    DESCRIPTION: str = "Kafka consumer worker for task analytics processing"


settings = Settings()