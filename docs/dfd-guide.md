Data Flow Diagrams

A structured analysis technique that employs a set of visual representations of the data that moves through the organization, the paths through which the data moves, and the processes that produce, use, and transform data.  
Why Data Flow Diagrams?

• Can diagram the **organization** or the **system** • Can diagram the **current** or **proposed** situation • Can facilitate **analysis** or **design**

• Provides a good bridge from analysis to design • Facilitates communication with the user at all stages

2  
Types of DFDs

• **Current** \- how data flows now

• **Proposed** \- how we’d like it to flow • **Logical** \- the “essence” of a process • **Physical** \- the implementation of a process • **Partitioned physical** \- system architecture or high-level design  
Levels of Detail

• **Context level diagram** \- shows just the inputs and outputs of the system

• **Level 0 diagram** \- decomposes the process into the major subprocesses and identifies what data flows between them

• **Child diagrams** \- increasing levels of detail • **Primitive diagrams** \- lowest level of decomposition  
Recommended Progression

• Current logical diagrams  
– start with context level  
– decompose as needed for understanding • Proposed logical diagrams

– start at level where change takes place – decompose as far as possible

• Current physical diagrams  
– at level of change  
• Proposed physical diagrams – same levels as proposed logical

– lower levels become design  
Four Basic Symbols

Source/ Sink  
Data Flow

\#

Process

| \#  |
| :-: |

Data Store  
Context Level Diagram

• Just one process

• All sources and sinks that provide data to or receive data from the process

• Major data flows between the process and all sources/sinks

• No data stores  
Running Example

Course Registration: Context level Diagram

Professor

Class Request  
0  
Class roster

Student  
Payment Receipt

Course

Registration System

Student Schedule

Enrollment statistics

Registrar  
Level 0 Diagram

• Process is “exploded”

• Sources, sinks, and data flows repeated from context diagram

• Process broken down into subprocesses, numbered sequentially

• Lower-level data flows and data stores added  
Running Example

Course Registration: Current Logical Level 0 Diagram

1.0  
Class Request Student

| D1  |
| :-: |

Payment

Receipt

2.0  
Register

Student for Course  
Student and Course Data

Student Class Records

Student  
Class Record

Collect

Student Fee Payment  
Payment  
~~Information~~

|     |
| :-- |

D2 Student Payments Student  
Student Class Record Student Class Record  
Class Record

3.0

Produce Student Schedule  
4.0

Produce Class

Roster  
5.0

Produce

Enrollment Report

Student Schedule Class RosterEnrollment Report

Student Professor Registrar  
Child Diagrams

• “Explode” one process in level 0 diagram • Break down into lower-level processes, using numbering scheme

• Must include all data flow into and out of “parent” process in level 0 diagram • Don’t include sources and sinks • May add lower-level data flows and data stores  
Running Example

Course Registration: Current Logical Child Diagram

| D3  |
| :-: |

1.1

Semester Schedule Available Seats

1.2  
Available Seats 1.3  
Class Request Valid Class Check

Check  
Feasible Class

Enroll

Error

| D4  |
| :-: |

Prerequisites Met

Student  
Record  
~~Request~~

Course Record

| D5  |
| :-: |

for

Availability  
~~Request~~

Error

| D1  |
| :-: |

Student

in Class

Student  
and Course

Data

Student Transcripts Course Catalogue Student Class Records  
Physical DFDs

• Model the implementation of the system • Start with a set of child diagrams or with level 0 diagram

• Add implementation details

– indicate manual vs. automated processes – describe form of data stores and data flows – extra processes for maintaining data  
Running Example

Course Registration: Current Physical Child Diagram

1.1

|     |
| :-- |

D3 Semester Schedule DB Available Seats

1.2  
Available Seats 1.3  
Class Request Advisement Check

Check  
Feasible Class

Enroll

Student Notified  
Prerequisites Met  
(manual)

~~Authorization~~  
for  
Availability (myUMBC)

~~Request~~  
Student in Class (STARS)

(verbally)Unavailability

Student

Student  
File

|     |
| :-- |

Course Description

|     |
| :-- |

Message

|     |
| :-- |

and Course Data

D4 Department Student File D5 Course Catalogue (text) D1 Semester Enrollment DB  
Running Example

Course Registration: Proposed Physical Child Diagram

1.1

|     |
| :-- |

D3 Semester Schedule DB Available Seats

1.2  
Available Seats 1.3  
Class Request Authorized Check

Check  
Valid Class

Enroll

Student Notified  
Prerequisites Met  
(automated)

~~Class Request~~  
for  
Availability (automated)

~~Request~~  
Student  
in Class  
(automated)

(email)Student

Student

Student  
Record

| D4  |
| :-: |

Course Record

| D5  |
| :-: |

Emailed

|     |
| :-- |

and Course Data

Registrar’s Student DB Course Catalogue DB D1 Semester Enrollment DB  
Partitioning a physical DFD

• Part of system design

• System architecture

– high-level design

– overall shape of system

– some standard architectures

• Decide what processes should be grouped together in the system components  
Running Example

Course Registration: Physical diagram (partitioned)

1.1

|     |
| :-- |

D3 Semester Schedule DB Available Seats

1.2  
Available Seats 1.3  
Class Request Authorized Check

Check  
Valid Class

Enroll

Student Notified  
Prerequisites Met  
(automated)

~~Class Request~~  
for  
Availability (automated)

~~Request~~  
Student  
in Class  
(automated)

(email)Student

Student

Student  
Record

| D4  |
| :-: |

Course Record

| D5  |
| :-: |

Emailed

|     |
| :-- |

and Course Data

Registrar’s Student DB Course Catalogue DB D1 Semester Enrollment DB  
Another Example

Perfect Pizza: Context Level Diagram

Management

Phone Number  
0  
Weekly Report

Customer  
Customer Order Customer Info

Customer Order

System

Cook Order Delivery Delivery

Cook

Person

Information

Customer Phone  
Another Example

Perfect Pizza: Current Logical Level 0 Diagram Customer Order

Number

1.0  
Find  
Customer

Record

Customer Information

2.0  
Take

Customer Order

Order  
Information

3.0  
Print

Delivery Order

Delivery  
Information

Delivery Person

Customer Info  
Customer Record

Order  
Information

|     |
| :-- |

Customer History

Discount Info

|     |
| :-- |

D1 Customer Master

Customer  
Record

5.0  
D2 Customer History

| D3  |
| :-: |

Sales Records

Sales Info

7.0  
6.0  
Send  
Order

to Cook

Cook  
Order

Customer Customer ~~Order~~

Add  
Customer Record

Weekly Report

Management  
Print  
Weekly Totals

Cook  
Another Example

Perfect Pizza: Current Logical Child Diagram

Customer

~~History~~

3.1

|     |
| :-- |

D2 Customer History Customer  
Determine Customer

Information

Discount 3.2  
Order

Information

Record

Discount

3.3  
Discount Amount

Print

Delivery

Instructions

Delivery

Information

| D3  |
| :-: |

Discount

Information

Sales Records  
Another Example

Perfect Pizza: Current Logical Child Diagram

5.1

Record  
Customer Information Raw  
5.2

Store

Customer Information  
~~Customer~~ Information

Customer

Record

Customer  
Record

D1 Customer Master  
Another Example

Perfect Pizza: Physical Child Diagram

Phoned ~~Customer~~

5.1

Recorded  
Syntax  
Errors

5.2

Valid Customer  
Cancelled Transaction

5.3  
Information

Phone  
Number  
Clerk Types Customer Information

| D1  |
| :-: |

~~Customer~~ Information  
System  
Validates Customer Information

Customer ~~Record~~

Information

5.4  
Format  
Clerk  
Visually

Confirms  
Cust. Info.

New Customer  
Customer ~~Information~~ DB  
Customer

Record  
Another Example

Perfect Pizza: Current Physical Level 0 Diagram

Customer

Phone  
Number

1.0  
Phoned  
Customer Order

2.0

3.0

Delivery  
Clerk Finds Customer Row

Customer Information  
Clerk Takes Customer Order

(by phone)

Customer & Order Info  
System Prints Delivery

Order

Delivery Printout

Person

Phoned Customer Info  
Customer Record

Cust. Info.  
Copy of Order Slip

|     |
| :-- |

Customer History Record

Customer History Record

|     |
| :-- |

D1Customer Spreadsheet  
D2 Customer History DB

8.0  
Mgr Updates

Customer  
Record

5.0

|     |
| :-- |

D3 Sales Records File

Copies of  
Order Slips

Copies of  
Order Slips  
& Del. Printouts 7.0  
Customer History (nightly)

Customer

Phoned  
Customer

Clerk Adds Customer

Mgr Prints  
Order

6.0  
Weekly Report Phone \# Row

Weekly Totals (batch)

Copy of  
Clerk Sends Order  
Management order slip Cook  
to Cook (paper)  
Another Example

Perfect Pizza: Proposed Physical Level 0 Diagram

Customer

Phone  
Number  
Phoned  
Customer Order

Order  
~~Info~~

Discount  
Info

| D3  |
| :-: |

Sales DB

1.0  
System Finds Customer

Record

Customer Information  
2.0  
Clerk Enters Customer Order

(by phone)

Order Info  
3.0  
System Prints Delivery

Order

Delivery Printout

Delivery Person

Phoned Customer Info  
Customer Record

Cust. Info.  
Order  
Info

|     |
| :-- |

Customer History Record

D1 Customer DB  
D2 Customer History DB

Customer Record

| D3  |
| :-: |

Sales DB

Sales  
5.0  
Clerk Adds Customer

Records

7.0  
System Prints  
Weekly Report Phone \# Record  
Cook Management

Weekly Totals (batch)  
Another Example

Perfect Pizza: Partitioned Physical Level 0 Diagram

Customer

Phone  
Number  
Phoned  
Customer Order

Order  
~~Info~~

Discount  
Info

| D3  |
| :-: |

Sales DB

1.0  
System Finds Customer

Record

Customer Information  
2.0  
Clerk Enters Customer Order

(by phone)

Order Info  
3.0  
System Prints Delivery

Order

Delivery Printout

Delivery Person

Phoned Customer Info  
Customer Record

Cust. Info.  
Order  
Info

|     |
| :-- |

Customer History Record

D1 Customer DB  
D2 Customer History DB

Customer Record

| D3  |
| :-: |

Sales DB

Sales  
5.0  
Clerk Adds Customer

Records

7.0  
System Prints  
Weekly Report Phone \# Record  
Cook Management

Weekly Totals (batch)  
Data Flow Diagramming Rules

• Processes

– a process must have at least one input – a process must have at least one output – a process name (except for the context level process) should be a verb phrase

• usually three words: verb, modifier, noun

• on a physical DFD, could be a complete sentence  
1.0

Gather Data

Demographic Data

Survey  
2.0

Compile Statistics

3.0  
ResponsesFinal  
Analyze Responses

Report  
2.0

Visa  
Authorization

2.0

Total

Records

2.0

QA

Process

BETTER

BETTER BETTER  
2.0

Check  
Customer Credit

2.0

Total

Sales

Records

2.0

Inspect Finished Products  
Data Flow Diagramming Rules

• Data stores and sources/sinks

– no data flows between two data stores; must be a process in between

– no data flows between a data store and a source or sink; must be a process in between

– no data flows between two sources/sinks • such a data flow is not of interest, or

• there is a process that moves that data

Customer Information

2.1

Store  
Customer

Data

Customer

Customer

Information Customer  
2.1

Store  
Customer Data

| D1  |
| :-: |

Data

Customer Data Customer

| D1  |
| :-: |

Data Customer Preferences

Customer Data

| D2  |
| :-: |

Preferences

Customer Preferences

| D2  |
| :-: |

Customer Preferences

Customer Information

2.1

Store  
Customer

Data

Customer

Data

Customer

Information

Customer

Data  
2.1

Store  
Customer Data

| D1  |
| :-: |

Customer Data

Customer

Preferences

| D1  |
| :-: |

Customer Data

Customer

Data

Customer

Preferences

2.2

Extract  
Customer Preferences

| D2  |
| :-: |

Customer Preferences

| D2  |
| :-: |

Customer Preferences

| D1  |
| :-: |

Customer

Customer

Data

Customer Data

| D1  |
| :-: |

Customer

Customer

Information

2.0

Store  
Customer

Data

Customer

Data

Customer Data

Doctor

Diagnosis

Patient  
Service

Information Bill

0

Medical Billing System  
Data Flow Diagramming Rules

• Data flows

– data flows are unidirectional

– a data flow may fork, delivering exactly the same data to two different destinations

– two data flows may join to form one only if the original two are exactly the same

– no recursive data flows

– data flows (and data stores and sources/sinks) are labelled with noun phrases

Order

Total

2.0

Total  
Daily

Sales  
1.0

Take  
Customer

Order

Customer

Order

Order

Information

3.0

Print

Delivery

Instructions

Order

Total

2.0

Total  
Daily

Sales  
1.0

Take  
Customer

Order

Order

Information

3.0

Print

Delivery

Instructions  
1.0

Take  
Customer

Order

Customer

Order  
2.0

Lookup  
Customer

Record

Customer

Address

Customer

Information

3.0

Print  
1.0

Take  
Customer

Order

Customer

Order

3.0

Print  
2.0

Lookup  
Customer

Record

Customer

Address

Delivery

Instructions  
Delivery

Instructions  
1.0 Get  
Customer  
2.0

Take

Order  
3.0

Process  
Customer  
DataCustomer Customer

Customer

Data

1.0

Get  
Customer Data

Customer Data  
Order

2.0

Take  
Customer Order

Data Order  
Order

3.0

Process Customer Order

1.0

Get  
Customer Data  
Customer

Data

Customer

~~Data~~

Only if these are **_exactly_** the same  
2.0

Take  
Customer Order

3.0

Validate Customer Data

Daily Sales  
1.0

Calculate Weekly Sales

Cumulative To-Date

Sales  
Data Flow Diagramming Guidelines

• The inputs to a process are different from the outputs

• Every object in a DFD has a unique name

Customer Data

Customer Data  
1.0

Validate Customer Data

1.0

Validate Customer Data

Customer Data

Valid

Customer Data  
Data Flow Diagramming Guidelines

• A data flow at one level may be decomposed at a lower level

• All data coming into and out of a process must be accounted for • On low-level DFDs, new data flows can be added to represent  
exceptional situations

Customer Phone

Customer Address  
Customer

Information

1.1

Get  
Customer

Phone

1.3

Request  
Customer

Address  
1.0

Get  
Customer

Address

Customer

Phone

Customer

~~Address~~  
Customer

Address

1.2

Lookup  
Customer

Address

Customer Phone

Customer

Information

1.1

Get  
Customer  
1.0

Get  
Customer Address

Customer Phone

Customer

Address

1.2

Lookup  
Customer

Invalid Phone Number Message

Customer

Address  
Phone

1.3

Request Customer Address  
Address

Customer ~~Address~~  
Data Elements

• Indivisible pieces of data

• Data flows and data stores are made up of data elements

• Like attributes on an ER diagram • The data elements of a data flow flowing in or out of a data store must be a subset of the data elements in that data store

Employee

Hours

Worked

| D1  |
| :-: |

Employee Master

Employee

Record

1.0

2.0

| D2  |
| :-: |

| D1  |
| :-: |

Employee Time File Employee Master

Employee Time

Record

Employee Record

Calculate Gross  
Pay

4.0

Print  
Employee  
Gross Pay

Net

Pay  
Calculate  
Withholding  
Amount

Withholding

3.0

Calculate

Net  
Check  
Reconciliation  
Paycheck  
Pay

Record Employee Paycheck

| D3  |
| :-: |

Check Reconciliation

Employee

Employee

| D1  |
| :-: |

Employee Master

| D4  |
| :-: |

Withholding Tables

Number of

Hours

Worked

5.0

Create

Dependents

Employee

Record

1.0  
Withholding Rates

2.0

| D2  |
| :-: |

| D1  |
| :-: |

Time  
Record

Employee

Time Record

Employee Time File Employee Master 6.0

Employee Time  
Record

Employee Record

Calculate Gross  
Pay

Gross

Pay

4.0

Print  
Gross Pay

Net  
Calculate  
Withholding  
Amount

Withholding

Amount

3.0

Calculate

Reconcile Pay

Paycheck Information

Employee Paycheck  
Pay

Net Pay

Check  
Check

Employee Paycheck

| D3  |
| :-: |

Reconciliation

Record

Check Reconciliation

Employee  
DFDs and ERDs

• DFDs and ERDs are both used to model systems, but they show two very different perspectives on the system

• A DFD shows what the system **_does_** as well as the **_data_** that the system manipulates • An ERD shows **only** the **_data_** that the system manipulates.  
DFDs and ERDs (cont.)

• Entities on an ERD often (but not always) correspond to data stores on a DFD

• Attributes on an ERD usually correspond to data elements (listed in the data dictionary) that make up the data store and data flows on a DFD

• Relationships on an ERD **do not** correspond to processes on a DFD.

• Sources and sinks on a DFD usually **do not** show up as entities on an ERD  
Example DFD and ERD Customer

1.0

Take

Order

2.0  
**DFD** 3.0

Places  
Cook Customer Order

Name Hours NameAddress Inventory

Convert Order to Cooking Instructions

Cooking  
Processed Order

Convert Order to Ingredient List

Item Quantity

Instructions Ingredients

|     |
| :-- |

D1 Order Log

Cook Inventory Processing

**Incorrect ERD**  
Example DFD and ERD OrderId  
Customer 1.0

**DFD**Order Contains  
Time

Date

ItemQuantity

Take

Order

2.0

3.0

Item  
Includes

Ingredient

Quantity

Ingredient

Description

Convert Order to Cooking Instructions

Cooking  
Processed Order

Convert Order to Ingredient List

ItemId ItemName

Requires Index

Cooking

Instructions

Instructions Ingredients

|     |
| :-- |

D1 Order Log

Cook Inventory Processing

StepId Description

**Correct ERD**
