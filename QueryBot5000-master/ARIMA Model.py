from matplotlib import pyplot as plt
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split

from statsmodels.tsa.stattools import adfuller
from numpy import log

from statsmodels.graphics.tsaplots import plot_acf, plot_pacf
import matplotlib.pyplot as plt
from statsmodels.graphics.tsaplots import plot_acf, plot_pacf

import matplotlib.pyplot as plt
from statsmodels.tsa.arima.model import ARIMA
from sklearn.metrics import mean_squared_error, mean_absolute_error
from statsmodels.stats.diagnostic import acorr_ljungbox

# Generate example dataset
startDate = '2020-01-01'
endDate = '2024-01-01'
numDays = (pd.to_datetime(endDate) - pd.to_datetime(startDate)).days + 1

# Generate dates by day
dates = pd.date_range(start = startDate, end = endDate, freq = 'D')

# Generate random query rates
np.random.seed(0)  # For reproducibility
queryRate = np.random.randint(0, 200, size = numDays)  # Random query rates between 0 and 200
#normalizedQueryRate = np.random.normal(loc=100, scale=10, size=len(dates))  # Normalized set of query data

# Create a DataFrame
df = pd.DataFrame({'Date': dates, 'Query Rate': queryRate})
df.set_index('Date', inplace = True)
df.head()

# Fill in missing values
df = df.iloc[1:]
df = df.fillna(method='ffill')

# Alternatively drop missing values
# training = training.dropna(how='all')

# Calculate Z-score
z_scores = (df - df.mean()) / df.std()
threshold = 2
outliers = df[abs(z_scores) > threshold]

print("Z-Score Outliers:")
print()
print(outliers)

# Highlight outliers graphically
plt.figure(figsize=(10, 5))
plt.scatter(outliers.index, outliers.values, color='red', label='Outliers')
plt.plot(df, label='Imported Data', color='blue')

plt.title('Z-score Outlier Detection')
plt.xlabel('Datetime')
plt.ylabel('Query Rate')
plt.legend()
plt.show()

result = adfuller(df['Query Rate'].dropna())
# Check if p-value < significance value(0.05)
print('p-value: %f' % result[1])

# Creating Date Ranges for Specific Examinations if Desired
year2020 = pd.date_range(start = '1/1/2020', end = '1/1/2021', freq = 'M')
year2021 = pd.date_range(start = '1/1/2021', end = '1/1/2022', freq = 'M')

# Visualize Data
df['Query Rate'].asfreq('M').plot()
plt.title('Query Rates 2020-2024')
plt.show()

# Perform differencing if data requires further stabilizing
plt.rcParams.update({'figure.figsize':(9,7), 'figure.dpi':120})

# Original Series
fig, axes = plt.subplots(2, 2, sharex=True)
axes[0, 0].plot(df['Query Rate'])
axes[0, 0].set_title('Original Plot')
plot_acf(df['Query Rate'], ax=axes[0, 1])

# 1st Differencing - in this case it doesn't matter

df_diff = df.diff().dropna()

axes[1, 0].plot(df_diff['Query Rate'])
axes[1, 0].set_title('1st Order Differencing')
plot_acf(df_diff['Query Rate'], ax=axes[1, 1], lags = 1)

plt.tight_layout()
plt.show()

# Split dataset into training and testing sets (80% training, 20% testing)
trainingData_Size = int(len(df) * 0.8)
training, testing = df[:trainingData_Size], df[trainingData_Size:]
# testing, validation = temp[:testing_size], temp[testing_size:]

# Print sizes of training and testing sets
print("Training set size:", len(training))
print("Testing set size:", len(testing))

# Plot PACF to visually inspect lags
fig, axes = plt.subplots(figsize=(8, 4))
plot_pacf(training, ax=axes)
plt.show()

# Plot ACF to visually inspect lags
fig, axes = plt.subplots(figsize=(8, 4))
plot_acf(training, ax=axes)
plt.show()

# Fit ARIMA model with optimal parameters
model = ARIMA(training['Query Rate'], order=(1,1,1))
fittedModel = model.fit()
print(fittedModel.summary())

# Adjust ARIMA model based on p values - here with fit without the AR term(0.306 > 0.05)
ar_removedModel = ARIMA(training['Query Rate'], order=(0,1,1))
ar_removedFitted = ar_removedModel.fit()
print("AR Removed Fitted Model:")
print()
print(ar_removedFitted.summary())

# Plot PACF and time series data side by side
fig, axes = plt.subplots(1, 2, figsize=(12, 4))
plot_pacf(training, ax=axes[0])
training.plot(ax=axes[1])
plt.show()

# Plot residual errors - check for stability
residuals = pd.DataFrame(ar_removedFitted.resid)
fig, ax = plt.subplots(1,2)
residuals.plot(title="Residuals", ax=ax[0])
residuals.plot(kind='kde', title='Density', ax=ax[1])
plt.show()

predictions = list()
for i in range(len(testing)):
    output = ar_removedFitted.forecast()
    predictions.append(output[0])

#print(predictions[:10])
#print(predictions[-10:])

# Calculate evaluation metrics
mse = mean_squared_error(testing, predictions)
rmse = np.sqrt(mse)
mae = mean_absolute_error(testing, predictions)

print("Mean Squared Error (MSE):", mse)
print("Root Mean Squared Error (RMSE):", rmse)
print("Mean Absolute Error (MAE):", mae)