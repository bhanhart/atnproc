# ATN Message Processing Design Options

## Introduction

The intention of this document is to provide and evaluate alternative design options for an application that captures Aeronautical Telecommunication Network (ATN) messages, filters and converts them into a single-line ASCII representation, and store the results as CSV files.

## Target System Architecture

The system is split into two isolated environments: the operational environment and the support environment.

- The operational environment runs the ATN Router service on two virtual machines in a high-availability cluster (Corosync/Pacemaker).
- The support environment consists of a single virtual machine that hosts data-processing and analysis tools.

File transfers are one-way: operational → support via `rsync`.

## Technical Constraints and Considerations

Network capture is performed with `tcpdump`. Third-party suppliers provide processing tools:

- Supplier A provides several Bash scripts and a single `awk` script to capture, filter, and format each ATN message into a single-line ASCII representation. Supplier A’s scripts are intended to run as independent cron jobs.
- Supplier B provides a mandatory binary utility that converts the single-line ASCII format into CSV rows.

When evaluating design options:

- Network capture is always performed in the operational environment
- Supplier B’s binary is always used.
- The filtering and formatting steps can be freely allocated to either the operational or support environment.
- Replacing Supplier A’s Bash scripts with one or more Python components is a viable option to improve robustness, testability, and maintainability.
