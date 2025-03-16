# AI Timetable - Prolog-based School Timetabling System

This project is based on the work of students from the **Representation of Knowledge** course (2022-2023) and builds upon the work of **Markus Triska** in *The Power of Prolog*. More details about the original work can be found at: [The Power of Prolog - Timetabling](https://www.metalevel.at/prolog/timetabling/#).

## Introduction

AI Timetable is a **constraint-based** school timetabling system implemented in **Prolog**. The system allows users to define timetabling constraints and generates feasible schedules using **constraint logic programming (CLP)**. The backend is built using **SWI-Prolog's HTTP server libraries** to provide a web-based interface.

A live test version of the server is available at: [http://51.20.191.101/](http://51.20.191.101/).

## Features
- Web interface to input timetabling constraints
- Uses **constraint logic programming (CLP)** for efficient scheduling
- Implements a **Prolog HTTP server** to process timetable generation requests
- Dynamically stores timetable rules and facts in the knowledge base

## Deployment on AWS

To deploy and run this server on an AWS instance:

### 1. Install SWI-Prolog
```bash
sudo apt update
sudo apt install swi-prolog
```

### 2. Clone the Repository
```bash
git clone https://github.com/YOUR_GITHUB_REPOSITORY.git
cd ai-timetable
```

### 3. Start the Server
Launch the server with:
```bash
swipl -s server.pl -g start -t halt
```

### 4. Stop the Server
To stop the server:
```bash
swipl -s server.pl -g stop -t halt
```

### 5. Run in Background with nohup
To keep the server running even after logout:
```bash
nohup swipl -s server.pl -g start -t halt &
```

## Key Elements of `server.pl`

### 1. HTTP Server Setup
The server uses **SWI-Prolog's HTTP library** to handle web requests.
```prolog
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
```

### 2. Handling Requests
The **root page (`/`)** serves the input form:
```prolog
:- http_handler(root(.), index_page, []).
```
The **timetable generation page (`/aitt`)** processes user input and generates a schedule:
```prolog
:- http_handler(root(aitt), generate_timetable, [method(post)]).
```

### 3. Processing Input
Constraints are **parsed and stored dynamically** in the knowledge base before scheduling:
```prolog
assertz(class_subject_teacher_times(Class, Subject, Teacher, Hours)).
```

### 4. Constraint Solving
The timetable is generated using **constraint logic programming (CLP(FD))**.
```prolog
:- use_module(library(clpfd)).
```
Schedules are computed by ensuring constraints like:
- No teacher assigned to multiple classes at the same time
- Each class has the required number of lessons per subject
- Room allocations are respected

## Contributors
This project was developed as part of the **Representation of Knowledge** course (2022-2023). It is inspired by the work of **Markus Triska** (*The Power of Prolog*).

For more details, visit: [The Power of Prolog - Timetabling](https://www.metalevel.at/prolog/timetabling/#).

