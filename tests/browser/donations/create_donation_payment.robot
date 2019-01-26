*** Settings ***

Resource        tests/NPSP.robot
Suite Setup     Open Test Browser
Suite Teardown  Delete Records and Close Browser


*** Test Cases ***

Create Donation and Opportunity and Create Payment Manually
    [tags]  unstable
    &{contact} =  API Create Contact    Email=skristem@robot.com
    &{opportunity} =  API Create Opportunity    &{Contact}[AccountId]    Donation    Name=Sravani $100 donation
    Go To Record Home  &{opportunity}[Id]
    Select Tab    Related
    Click Related List Button    Payments    New
    Select Window
    Populate Field    Payment Amount    100
    Click Dropdown    Payment Method
    Click Link    link=Credit Card
    Open Date Picker    Payment Date
    Pick Date    Today
    Click Modal Button        Save
    Verify Occurrence    Payments    1
