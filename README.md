# Wallet Top-up and KYC

Candidate: Vipul Rathod


## How to run

- Project version:

Flutter 3.47.0 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 4cf2416426 (2 months ago) • 2026-08-11 11:53:49 -0700
Engine • hash 59d54a2b2896a6bbf356c94b7fac7b9e235bdacd (revision 5f77625673) (2 months ago) • 2026-08-11 16:38:36.000Z
Tools • Dart 3.13.0 • DevTools 2.60.0

- Exact commands: 
- --dart-define values:

command - 
flutter run --dart-define=API_BASE_URL=http://10.69.50.57:3002


- Devices / emulators tested on:
- Physical Device (OnePlus & Vivo)

## Architecture

1. Feature wise divided as 
2. KYC flow
3. Wallet flow

State -
1. Getx used for statemgnt

Folder stucture :
/core
1. contain routing and navigation
2. along with used metwork (dio) as apiclient for api requests
3. plaatform channel added for screenshot prevention 

/data

for both KYC and Wallet flow - 
1. it consist model class for api response parsing 
2. repository class where acrual api call is there using apiClient (dio)
3. storage we use for lcoal storage
like adjust step in kyc flow or wallet flow for maintain order id for retry etc

/presentation
for both KYC and Wallet flow -
1. it contain Binding which is attached to routes 
2. state which contain controller & FE validations
3. actual ui screen and widget place here (homepage,kycpage,wallet pages etc)



## Feature checklist

Status is Done, Partly or Not done. Give the file or class and a short note.

| Item | Status | File / class | Note |
| --- | --- | --- | --- |
| Wallet: enter amount (rupees to paise) and Pay ------done
File - lib/presentation/wallet/pages/wallet_top_up_page.dart
Note: User enter amount (sent in paise format to api) validation added 

| Create order with POST /api/orders and Idempotency-Key |  |  |  | ------ done
File - lib/data/wallet/repository/wallet_repository.dart
Note: Yes created Idempotency-key -idempotencyKey: _uuid.v4(), 

| Pay with POST /gateway/pay, then POST /api/payments/verify |  |  |  | -------- done
File - lib/data/wallet/repository/wallet_repository.dart
Note: both api added and also use shared_preference for this so if user close app in middle or
payment failed so we can retry payment



| Balance shown only from GET /api/wallet |  |  |  | --------- done
File - lib/data/wallet/repository/wallet_repository.dart
Note: Yes no manual update we get response and its come from api and always user see its value on
File - lib/presentaion/wallet/pages/wallet_home_page.dart and if order is in pending we poll the api so 
get update as order status updated




| Declined, slow, pending and unknown-result messages |  |  |  | ------------ done
File - lib/presentaion/wallet/pages/wallet_home_page.dart
File - lib/presentaion/wallet/pages/wallet_top_up_page.dart
Note: there is Last top-up section where user get info about its last order and its status and what to do next 
eg. Order is pending then we show messge as order id and status and notify user to wait for process completion 
do not make another payment and such as there is 2 attempt for failed payment with same order id as retry added

| Never charge twice for one order |  |  |  | ------ done
Note: No,
button is also disbale and added extra validation

| Kill the app during a payment: true state on reopen |  |  |  | ----- done
Note: used session for preserve the orderid and also 
we clear pending order once processing is done or processing order is endded


| Double taps do not start two payments |  |  |  | ---------- done
Note: Not posible as button disble and if first request there so somehow if click also 
it doest call pay function it return abck

| KYC: start session with Idempotency-Key |  |  |  | ---------- done
File - lib/data/wallet/respository/wallet_repositiroy.dart
Yes used uuid package for this 





| KYC: document step (PAN / Aadhaar / Passport) with validation |  |  |  | -------- done
File - lib/presentaion/kyc/pages/kcy_page.dart
File - lib/presentaion/kyc/state/kyc_controller.dart
File - lib/presentaion/kyc/state/kyc_document_validation.dart
Note: validation added using regex for all doc type


| KYC: face check step (score 0 to 1) |  |  |  | ------------- done 
File - lib/presentaion/kyc/pages/kcy_page.dart
File - lib/presentaion/kyc/state/kyc_controller.dart
Note: as per get api response and adjust step count and also store data in session



| KYC: show verified, manual review, failed with retries left, blocked |  |  |  | -------- done
File - lib/presentaion/kyc/pages/kcy_page.dart
File - lib/presentaion/kyc/state/kyc_controller.dart
Note: all 3 stats handle and as per that ui will change and in manual way it check the status and 
once updated ui will update as per that every screen has pull down refresh added 
and poling also there for auto update

| KYC: resume at the right step after a kill |  |  |  | ----------------- done
File - lib/presentaion/kyc/pages/kcy_page.dart
File - lib/presentaion/kyc/state/kyc_controller.dart
Note: as per get api response and adjust step count and also store data in session
so user go to correct step if come up with close app and reopen

| Document number masked, not logged, not stored |  |  |  | ------------ done
Note: Document number is not stored just show masked number which got from api after kyc verify

| Kotlin EventChannel for network state + offline banner |  |  |  |  -------------Not Done
Note: Not added

| Kotlin MethodChannel for screenshot blocking on KYC screens |  |  |  | --------- Partialy Done
FLUTTER - lib/core/service/screenshot_protection.dart
KOTLIN -  android/app/src/main/MainActivity.kt
Note: added but notworking as expected 



| Expected: at least four automated tests |  |  |  | ---------- not done
Note: Not added

| Expected: Diagnostics screen |  |  |  | ----------- not done
Note: Not added

| Expected: GitHub Actions (flutter analyze, flutter test) |  |  |  | ---------- not done
Note: Not added


| Optional: statement / receipt / ask support |  |  |  | ----------- not done
Note: Not added


## How I handled the hard parts


### Idempotency key of a top-up attempt
Get <UUID> package for genrate the key 



### A pending payment
show last top-up card where all info is visible like if payment is pending then wait for process 
dont do payment again like this we show friendly message and status to user so user can easily understand 
the concern 

### Where the wallet balance comes from
wallet balance come from api no manual update is there there is timmer used for that so,
if any payment is in queue and get updated so it will reflect changes asap

### Killing the app in the middle of a payment


### Double taps
pay button is disable so doube tap is posible still checking like
already request is processesing then return back so no double request proceed 

### The KYC steps and resuming them
used session Shared_preference for that so i get steps from api of session as per that 
adjust the logic like if user close app after first step (docuent verification) then 
when user close app and come then start from step 2 livelyness as we get data and as per that we addd
condition and start with step 2 (condition added via step key)



### The document number and other sensitive data
document not stored in device or any local storage 
when we response from api its already masked (i.e XX00)
we use togle for number to enhance security (just like password field obscure value)

### The two Kotlin channels and how they are cleaned up
Event chanel is not impemented
I was implemmeneted method channel but it not working need to rectify the issue 
using lib/core/service/screenshot_prottection.dart and mainactivity.kt


### How GetX controllers are created and disposed
I used route 
1. lib/core/app_page.dart which contain routes and added binding over there so when screen open our controller 
is there for further used KYC & Wallet


## Server behaviours I tried
I run server useing node server.js 
using localhost/admin run and check different scenario 
as
1. payment (ok,slow,fail,pending,tempered)
2. Time (4,12,30) seconds
3. KYC status (normal,fail)
4. see stats in local machin (order stats,wallet stats in paise)

| Admin setting | What I saw |
| --- | --- |
|  |  |

## The change request

What was asked, what I changed, and where.

## Tests

What they cover and how to run them.

## Not finished
Event chanel impemnetaion is missing 
Method channel code is added but not working as expected (so screenshot & internet check is missing)

## Risks and next steps

## Assumptions and decisions

## How I used AI

AI used for -
1. regex for validation (pan,adhar,passport)
2. UI/UX design of screen

## Time spent
1. project setup & api testing - 1hr
2. KYC - 2.30hr
3. Wallet - 4hr
4. testing (admin & app) - 1.30

| Part | Time |
| --- | --- |
|  |  |

---

Screenshots of every screen in light and dark theme go in docs/screens and are linked here.
attache in mail