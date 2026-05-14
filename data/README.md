# Data

`ab_test_data.csv` - исходный CSV с тестового задания (1.8M строк user-day, ~80МБ).
Не закоммичен в репозиторий из-за размера. Положи файл сюда и запускай notebook.

Обработанные файлы (закоммичены):
- `user_level.csv` - агрегация per user (100k строк)
- `daily.csv` - per day per group
- `retention.csv` - D1, D3, D7, D14, D28 retention по группам
