#!/usr/bin/env python3
import fnmatch
import csv
import time
from datetime import datetime, timedelta
import datetime as dt
import sys
import os
import pickle
import numpy as np
import shutil
import argparse

import matplotlib.pyplot as plt
import matplotlib.ticker as plticker
import matplotlib.dates as mpdates
import matplotlib as mpl

from sortedcontainers import SortedDict

DATA_DICT = {
        #'admission': "../synthetic_workload/noise/",
        'admission': "../clustering/timeseries/admissions/admission-combined-results-full/",
        'oli': "oli-combined-results/",
        'tiramisu': 'combined-results/',
        #'tiramisu': 'tiramisu-combined-csv/',
        }

# Only looks at the csv files for the first 10 templates for testing purpose
TESTING = False

# The number of the largest clusters to consider for coverage evaluation and
# forecasting
MAX_CLUSTER_NUM = 3

# If it's the full trace used for kernel regression, always aggregate the data
# into 10 minutes intervals
FULL = True

# If it's the noisy data evaluation, use a smaller time gap to calculate the
# total volume of the largest clusters. In the future we should automatically
# adjust this to the point where the worklaod has shifted after we detect that a
# shift happened (i.e., the majority of the workload comes from unseen queries).
# And of course a long horizon prediction is hard to work if the shift only
# happened for a short period.
NOISE = False

if FULL:
    AGGREGATE = 10
else:
    AGGREGATE = 1

if NOISE:
    LAST_TOTAL_TIME_GAP = 1200 # seconds
else:
    LAST_TOTAL_TIME_GAP = 86400 # seconds

DATETIME_FORMAT = "%Y-%m-%d %H:%M:%S" # Strip milliseconds ".%f"


def LoadData(input_path):
    print(f"line 61 - enter LoadData with input path {input_path}")
    total_queries = dict()
    templates = []
    min_date = datetime.max
    max_date = datetime.min
    data = dict()
    data_accu = dict()

    cnt = 0
    for root, dirs, files in os.walk(input_path):
        if root.endswith('.zip.anonymized'):
            for csv_file in sorted(files):
                if not csv_file.endswith('.csv'):
                    #print(f"Ignoring non-CSV file: {csv_file}")
                    continue

                print(csv_file)

                try:
                    #take care of UnicodeDecodeError with UTF-8
                    with open(os.path.join(root, csv_file), 'r', encoding='utf-8', errors='replace') as f:
                        # Read the entire content and replace NULL bytes - csv NUL line error
                        content = f.read().replace('\x00', ' ')
                        f = content.splitlines()

                        reader = csv.reader(f)
                        # Skip the first row - column labels
                        next(reader, None)
                        queries, template = next(reader)

                        # To make the matplotlib work...
                        template = template.replace('$', '')

                        # Assume we already filtered out other types of queries when combining template csvs
                        #statement = template.split(' ',1)[0]
                        #if not statement in STATEMENTS:
                        #    continue

                        #print queries, template
                        queries_datetime = datetime.strptime(queries, "%Y-%m-%d %H:%M:%S")
                        total_queries[template] = int(queries_datetime.timestamp())
                        #print queries
                        templates.append(template)

                        # add template
                        data[template] = SortedDict()
                        data_accu[template] = SortedDict()

                        total = 0

                        #Iterate through every line in the CSV file
                        for line in reader:
                            time_stamp = datetime.strptime(line[0], DATETIME_FORMAT)
                            count = int(line[1])

                            data[template][time_stamp] = count

                            total += count
                            data_accu[template][time_stamp] = total

                            min_date = min(min_date, time_stamp)
                            max_date = max(max_date, time_stamp)
                except StopIteration:
                    print(f"StopIteration encountered in file {csv_file}. Moving onto next file")
                    continue

                cnt += 1

                if TESTING:
                    if cnt == 10:
                        break

    templates = sorted(templates)

    return min_date, max_date, data, data_accu, total_queries, templates

def GenerateData(min_date, max_date, data, data_accu, templates, assignment_dict, total_queries,
        num_clusters, output_csv_dir):
    plotted_total = 0
    plotted_cnt = 0
    totals = []

    coverage_lists = [[] for i in range(MAX_CLUSTER_NUM)]

    top_clusters = []

    online_clusters = dict()

    last_date = min_date
    if FULL:
        # Normal full evaluation
        assignment_dict = assignment_dict[0:]
        # used for the micro evaluation only for the spike patterns
        #assignment_dict = assignment_dict[365:] 
    for current_date, assignments in assignment_dict:
        cluster_totals = dict()
        date_total = 0

        for template, cluster in assignments.items():
            if cluster == -1:
                continue

            last_total_date = next(data_accu[template].irange(maximum = current_date, reverse =
                True))
            if (current_date - last_total_date).seconds < LAST_TOTAL_TIME_GAP:
                template_total = data_accu[template][last_total_date]
            else:
                template_total = 0
            date_total += template_total

            if not cluster in cluster_totals:
                cluster_totals[cluster] = template_total
            else:
                cluster_totals[cluster] += template_total

        if len(cluster_totals) == 0:
            last_date = current_date
            continue

        sorted_clusters = sorted(cluster_totals.items(), key = lambda x: x[1], reverse = True)

        sorted_names, sorted_totals = zip(*sorted_clusters)

        current_top_clusters = sorted_clusters[:MAX_CLUSTER_NUM]
        print("Line 185 - GenerateData Current Date and Current Top Clusters")
        print(current_date, current_top_clusters)

        if FULL:
            record_ahead_time = timedelta(days = 30)
        else:
            record_ahead_time = timedelta(days = 8)

        for c, v in current_top_clusters:
            if not c in online_clusters:
                online_clusters[c] = SortedDict()
                for template, cluster in assignments.items():
                    if cluster != c:
                        continue

                    if FULL:
                        start_date = min_date
                    else:
                        start_date = max(min_date, last_date - dt.timedelta(weeks = 4))
                    for d in data[template].irange(start_date, last_date + record_ahead_time, (True, False)):
                        if not d in online_clusters[cluster]:
                            online_clusters[cluster][d] = data[template][d]
                        else:
                            online_clusters[cluster][d] += data[template][d]


        current_top_cluster_names = next(zip(*current_top_clusters))
        for template, cluster in assignments.items():
            if not cluster in current_top_cluster_names:
                continue

            for d in data[template].irange(last_date + record_ahead_time, current_date +
                    record_ahead_time, (True, False)):
                if not d in online_clusters[cluster]:
                    online_clusters[cluster][d] = data[template][d]
                else:
                    online_clusters[cluster][d] += data[template][d]

        top_clusters.append((current_date, current_top_clusters))

        for i in range(MAX_CLUSTER_NUM):
            coverage_lists[i].append(sum(sorted_totals[:i + 1]) / date_total)

        last_date = current_date

    coverage = [ sum(l) / len(l) for l in coverage_lists]

    for c in online_clusters:
        if (len(online_clusters[c]) < 2):
            continue
        l = online_clusters[c].keys()[0]
        r = online_clusters[c].keys()[-1]

        n = (r - l).seconds // 60 + (r - l).days * 1440 + 1 
        dates = [l + dt.timedelta(minutes = i) for i in range(n)]
        v = 0
        #for d, v in online_clusters[c].items():
        for d in dates:
            if d in online_clusters[c]:
                v += online_clusters[c][d]
            if d.minute % AGGREGATE == 0:
                WriteResult(output_csv_dir + "/" + str(c) + ".csv", d, v)
                v = 0

    return top_clusters, coverage

def WriteResult(path, date, data):
    with open(path, "a") as csvfile:
        writer = csv.writer(csvfile, quoting = csv.QUOTE_ALL)
        writer.writerow([date, data])

def Main(project, assignment_path, output_csv_dir, output_dir):
    print(f"project {project} assignment_path: {assignment_path}")
    # Read in input pickle file to get clustering assignments
    with open(assignment_path, 'rb') as f:
        num_clusters, assignment_dict, _ = pickle.load(f)

    min_date, max_date, data, data_accu, total_queries, templates = LoadData(DATA_DICT[project])
    #print(f"Line 261 - Main method exits LoadData with data {data}\n data_accu: {data_accu}\n total_queries: {total_queries}")
    #print(f"templates: {templates}")

    print(f"output directory creating in case: {output_dir}")
    if not os.path.exists(output_dir):
        print("creating output directory")
        os.makedirs(output_dir)

    if os.path.exists(output_csv_dir):
        shutil.rmtree(output_csv_dir)
    os.makedirs(output_csv_dir)

    top_clusters, coverage = GenerateData(min_date, max_date, data, data_accu, templates, assignment_dict,
            total_queries, num_clusters, output_csv_dir)

    #prints clustering-results/online-clustering/tiramisu-0.8-assignments.pickle [0.2024771141772688, 0.34111263676435083, 0.44064638143904383]
    print("Assignment Path and Coverage:")
    print(assignment_path, coverage)

    with open(output_dir + "coverage.pickle", 'wb') as f:  # Python 3: open(..., 'wb')
        pickle.dump((top_clusters, coverage), f)


# ==============================================
# main
# ==============================================
if __name__ == '__main__':
    aparser = argparse.ArgumentParser(description='Generate Cluster Coverage')
    aparser.add_argument('--project', help='The name of the workload')
    aparser.add_argument('--assignment', help='The pickle file to store the clustering assignment')
    aparser.add_argument('--output_csv_dir', help='The directory to put the output csvs')
    aparser.add_argument('--output_dir', help='Where to put the output coverage files')
    args = vars(aparser.parse_args())

    print(f"output csv directory being received: {args['output_csv_dir']}")
    print(f"output csv directory being received: {args['output_dir']}")

    #docker run cluster-data --project tiramisu --assignment clustering-results/online-clustering/tiramisu-0.8-assignments.pickle --output_csv_dir clustering-results/cluster-coverage --output_dir tiramisu
    Main(args['project'], args['assignment'], args['output_csv_dir'], args['output_dir'])

    while True:
        time.sleep(1)

