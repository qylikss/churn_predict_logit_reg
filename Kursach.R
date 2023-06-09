date_df<-read.csv(file='/Users/qylikys/R/Kursach/transactions.csv', 
                  header=T, sep='\t', row.names=NULL)
# Предобработка данных ----------------------------------------------------
date_df <- data.frame(date_df)
df <- data.frame(date_df)
df$Сумма.продажи <- as.numeric(gsub('NULL', '0', df$Сумма.продажи))
df$Сумма.без.скидки <- as.numeric(gsub('NULL', '0', df$Сумма.без.скидки))
df$Дата.транзакции <- as.Date(df$Дата.транзакции, format="%d/%m/%Y")
prelast_df <- df
last_df <- df
n <- nrow(df)
if(!("dplyr" %in% installed.packages())){
  install.packages("dplyr") 
}
library(dplyr)
prelast_month <- as.Date('01/06/2022', format = "%d/%m/%Y")
last_month <- as.Date('01/10/2022', format = "%d/%m/%Y")
df <- filter(df, 
             Дата.транзакции < prelast_month &
               Кол.во - as.integer(Кол.во) == 0 &
               Сумма.без.скидки != 0)

# Функции для группировок -------------------------------------------------
group_by_check <- function(df){ #Функция группировки по чеку
  sale_sum <- aggregate(df, Сумма.продажи ~ Чек, FUN=sum) #Общая сумма продажи
  marja_sum <- aggregate(df, Маржа ~ Чек, FUN=sum) #Общая маржа
  count_pos <- aggregate(df, Кол.во ~ Чек, FUN=sum) #Кол-во позиций в чеке
  unique_pos <- summarise(group_by(df, Чек), 
                          Уникальные.товары=length(unique(Товар))) #Уникальные
  client <- summarise(group_by(df, Чек), Клиент=Клиент[1]) #Клиенt
  date <- summarise(group_by(df, Чек), Дата.транзакции=Дата.транзакции[1])
  df_check <- data.frame(date[2],
                         sale_sum[1],
                         client[2],
                         unique_pos[2],
                         count_pos[2],
                         sale_sum[2],
                         marja_sum[2])
  df_check <- df_check[order(df_check$Дата.транзакции, 
                             decreasing = F), ] 
  return(df_check)
}
#Функция для рассчета среднего интервала ммжду месяцами
mean_int <- function(arr){ 
  summ = 0
  n = length(arr)
  if (n != 1){
    for (i in (1:(n-1))){
      day_diff = as.numeric(gsub(' days', '', 
                                 as.Date(arr[i+1], 
                                         format = "%d/%m/%Y") - 
                                   as.Date(arr[i],
                                           format = "%d/%m/%Y")))
      summ = summ + day_diff
    }
  }
  else{
    summ = 0
  }
  return(signif(summ / n, digits = 4))
}
#Функция для группировки по клиентам
group_by_client <- function(df_check, for_last_month){
  sale_sum <- aggregate(df_check, Маржа ~ Клиент, FUN=sum) #Принес
  loss_sum <- summarise(group_by(df_check, Клиент), Унес=
                          (sum(Сумма.продажи) - sum(Маржа))) #Унес
  count_check <- aggregate(df_check, Чек ~ Клиент, FUN=length) #Кол-во чеков
  first_date <- summarise(group_by(df_check, Клиент), Посещение1=
                            Дата.транзакции[1]) #Первое посещение
  diff_date <- summarise(group_by(df_check, Клиент), Разница= as.numeric(
    gsub(' days', '',
         Дата.транзакции[length(Дата.транзакции)] - 
           Дата.транзакции[1]))) #Разница посл. и 1 дня 
  passed_time <- summarise(group_by(df_check, Клиент), Прошло= as.numeric(
    gsub(' days', '',
         for_last_month - 
           Дата.транзакции[length(Дата.транзакции)]))) #Прошло дней
  date_int <- summarise(group_by(df_check, Клиент), Средний.интервал=
                          mean_int(Дата.транзакции))
  df_client <- data.frame(sale_sum[1],
                          count_check[2],
                          loss_sum[2],
                          sale_sum[2],
                          first_date[2],
                          date_int[2],
                          diff_date[2],
                          passed_time[2]
  )
  return(df_client)
}

# Группировки -------------------------------------------------------------
#Группировки
df_check <- group_by_check(df) #Группировка по чекам
df_client <- group_by_client(df_check, prelast_month) #Группировка по клиентам
# Создание модели ---------------------------------------------------------
date_df$Дата.транзакции <- as.Date(date_df$Дата.транзакции, format="%d/%m/%Y")
date_df$Сумма.продажи <- as.numeric(gsub('NULL', '0', date_df$Сумма.продажи))
date_df$Сумма.без.скидки <- as.numeric(gsub('NULL', '0', 
                                            date_df$Сумма.без.скидки))
df_train <- filter(date_df, 
                   Дата.транзакции >=
                     prelast_month &
                     Дата.транзакции <
                     last_month &
                     Кол.во - as.integer(Кол.во) == 0 &
                     Сумма.без.скидки != 0)
new_month <- data.frame(Клиент = unique(df_train$Клиент), Присутствие = 1)
df_client_train <- dplyr::left_join(df_client, new_month, by = "Клиент")
df_client_train[is.na(df_client_train)] <- 0
model <-  glm(Присутствие ~ 
                Чек +
                Унес +
                Маржа +
                Средний.интервал +
                Разница +
                Посещение1 +
                Прошло, 
              data=df_client_train, family = binomial(link="logit"))
summary(model)
# Группировки для основного периода
new_df <- data.frame(prelast_df)
new_df$Сумма.продажи <- as.numeric(gsub('NULL', '0', new_df$Сумма.продажи))
new_df$Сумма.без.скидки <- as.numeric(gsub('NULL', '0', new_df$Сумма.без.скидки))
new_df$Дата.транзакции <- as.Date(new_df$Дата.транзакции, format="%d/%m/%Y")
new_df <- filter(new_df, 
                 Дата.транзакции > prelast_month &
                   Дата.транзакции < last_month &
                   Кол.во - as.integer(Кол.во) == 0 &
                   Сумма.без.скидки != 0)
new_df_check <- group_by_check(new_df)
new_df_client <- group_by_client(new_df_check, last_month)
# Группируем клиентов
future_month <- as.Date('01/11/2022', format = "%d/%m/%Y")
last_df <- data.frame(last_df)
last_df$Дата.транзакции <- as.Date(last_df$Дата.транзакции, format="%d/%m/%Y")
last_df <- filter(last_df, 
                  Дата.транзакции >= last_month &
                    Кол.во - as.integer(Кол.во) == 0 &
                    Сумма.без.скидки != 0)
temp_df <- summarise(group_by(last_df, Клиент), Присутствие=1)
# Прогнозируем на последний месяц -----------------------------------------
new_df_client_test <- dplyr::left_join(new_df_client, temp_df, by = "Клиент")
new_df_client_test[is.na(new_df_client_test)] <- 0

predictResult <- predict(model, newdata = new_df_client_test, type="response")
predictResult <- ifelse(predictResult >= 0.5, 1, 0 )
#Сравниваем результат прогнозирования с последний месяцем
#Матрица неточностей
library(caret)
confusionMatrix(factor(predictResult), factor(new_df_client_test$Присутствие))
#Точность модели
missing_classerr <- mean(predictResult != new_df_client_test$Присутствие)
print(paste( 'Accuracy =' , 1 - missing_classerr))
if(!("caTools" %in% installed.packages())){
  install.packages("caTools") 
}
library(caTools)
if(!("ROCR" %in% installed.packages())){
  install.packages("ROCR") 
}
library(ROCR)
# Кривая ROC-AUC
ROCPred <- prediction(predictResult, new_df_client_test$Присутствие)
ROCPer <- performance(ROCPred, measure = "tpr" ,
                      x.measure = "fpr" )
auc <- performance(ROCPred, measure = "auc" )
auc <-auc@y.values[[1]]
auc
# Построение кривой
plot(ROCPer)
plot(ROCPer, colorize = TRUE,
     print.cutoffs.at = seq( 0.1 , by = 0.1 ),
     main = "ROC CURVE" )
abline(a = 0 , b = 1 )
auc <- round(auc, 4)
legend(.65 , .10 , auc, title = "AUC" , cex = 0.8 )
summary(date_df)
