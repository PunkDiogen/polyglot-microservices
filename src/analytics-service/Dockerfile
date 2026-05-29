FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt


FROM python:3.12-slim
RUN adduser --system --group appuser
WORKDIR /app
COPY --from=builder /root/.local /home/appuser/.local
COPY . . 
RUN chown -R appuser:appuser /app
ENV PYTHONPATH=/home/appuser/.local/lib/python3.12/site-packages
ENV PATH=/home/appuser/.local/bin:$PATH
USER appuser
EXPOSE 8000
CMD [ "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000" ]