#!/usr/bin/env python3

import os
import sys
from datetime import datetime
import datetime as dt
import argparse
import csv
import numpy as np
import time
import itertools
import random
import pickle
import re
import math

import matplotlib.pyplot as plt
import matplotlib.ticker as plticker
import matplotlib.dates as mpdates
import matplotlib as mpl

from sortedcontainers import SortedDict

from sklearn.preprocessing import normalize
from sklearn.neighbors import NearestNeighbors

csv.field_size_limit(sys.maxsize)


# Only looks at the csv files for the first 10 templates for testing purpose
TESTING = False

# Whether use the KNN module from sklearn to accelerate finding the closest center
USE_KNN = True
# Which high-dimentional indexing algorithm to use
KNN_ALG = "kd_tree"


OUTPUT_DIR = 'online-clustering-results/'
STATEMENTS = ['select', 'SELECT', 'INSERT', 'insert', 'UPDATE', 'update', 'delete', 'DELETE']
# "2016-10-31","17:50:21.344030"
DATETIME_FORMAT = "%Y-%m-%d %H:%M:%S" # Strip milliseconds ".%f"

def LoadData(input_path):
    #print("enter load data")
    total_queries = dict()
    templates = []
    min_date = datetime.max
    max_date = datetime.min
    data = dict()

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
                        #reader = csv.reader(f, delimiter='\t')  # if data tab-delimited

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

                        #Iterate through every line in the CSV file
                        for line in reader:
                            time_stamp = datetime.strptime(line[0], DATETIME_FORMAT)
                            count = int(line[1])

                            data[template][time_stamp] = count

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

    return min_date, max_date, data, total_queries, templates

def Similarity(x, y, index):
    sumxx, sumxy, sumyy = 0, 0, 0
    for i in index:
        xi = x[i] if i in x else 0
        yi = y[i] if i in y else 0

        sumxx += xi * xi
        sumyy += yi * yi
        sumxy += xi * yi

    return sumxy / (math.sqrt(sumxx * sumyy) + 1e-6)

def ExtractSample(x, index):
    v = []
    for i in index:
        if i in x:
            v.append(x[i])
        else:
            #print("append 0 in extractSample")
            v.append(0)

    print(f"ExtractSample returning array of length {len(np.array(v))}: {np.array(v)}")
    return np.array(v)

def AddToCenter(center, lower_date, upper_date, data, positive = True):
    #print("enter AddToCenter")
    total = 0
    for d in data.irange(lower_date, upper_date, (True, False)):
        total += data[d]
        #print(f"data is {data[d]}")
        #print(f"manipulating center {center[d]}")

        if d in center:
            if positive:
                center[d] += data[d]
            else:
                center[d] -= data[d]
        else:
            center[d] = data[d]

        #print(f"center is now {center[d]}")

    #print(f"AddToCenter returning total {total}")
    return total

def AdjustCluster(min_date, current_date, next_date, data, last_ass, next_cluster, centers,
        cluster_totals, total_queries, cluster_sizes, rho):
    #print("enter AdjustCluster")
    n = (next_date - min_date).seconds // 60 + (next_date - min_date).days * 1440 + 1
    num_sample = 10000
    if n > num_sample:
        index = random.sample(range(0, n), num_sample)
    else:
        index = range(0, n)
    index = [ min_date + dt.timedelta(minutes = i) for i in index]
    new_ass = last_ass.copy()

    #center has no length below
    print(f"line 184 - centers is length {len(centers)}")
    # Update cluster centers with new data in the last gap
    for cluster in centers.keys():
        for template in last_ass:
            #print(f"examining template {template}")
            if last_ass[template] == cluster:
                #print(f"line 190 -Call AddToCenter")
                cluster_totals[cluster] += AddToCenter(centers[cluster], current_date, next_date, data[template])

    if USE_KNN:
        print("Building kdtree for single point assignment")
        clusters = sorted(centers.keys())
        #print has clusters = 0
        print(f"clusters from sorted centers keys: {clusters}")
        samples = list()

        print("USE_KNN entering for loop")
        for cluster in clusters:
            #print(f"for cluster interation {cluster}")
            #print(f"line 207 ExtractSample - x is {centers[cluster]}")
            sample = ExtractSample(centers[cluster], index)
            #print(f"sample {sample} from cluster {cluster}")
            samples.append(sample)

        #adjust as having sample length 1 has no neighbors
        if len(samples) <= 1:
            nbrs = None
        else:
            normalized_samples = normalize(np.array(samples), copy = False)
            nbrs = NearestNeighbors(n_neighbors=1, algorithm=KNN_ALG, metric='l2')
            nbrs.fit(normalized_samples)

        print("Finish building kdtree for single point assignment")
    

    cnt = 0

    print(f"line 223 - new_ass array is length {len(new_ass)}")
    for t in sorted(data.keys()):
        #print(f"AdjustCluster new_ass array of {t}: {new_ass[t]}")
        cnt += 1
        # Test whether this template still belongs to the original cluster
        if new_ass[t] != -1:
            #print("not equal -1 so set center")
            center = centers[new_ass[t]]
            #print(cnt, new_ass[t], Similarity(data[t], center, index))
            if cluster_sizes[new_ass[t]] == 1 or Similarity(data[t], center, index) > rho:
                #print("cluster size = 1 or similarity > rho - skipping")
                continue

        # the template is eliminated from the original cluster
        if new_ass[t] != -1:
            cluster = new_ass[t]
            #print(centers[new_ass[t]])
            #print([ (d, data[t][d]) for d in data[t].irange(min_date, next_date, (True, False))])
            cluster_sizes[cluster] -= 1
            print("line 242 - AddtoCenter")
            AddToCenter(centers[cluster], min_date, next_date, data[t], False)
            print("%s: template %s quit from cluster %d with total %d" % (next_date, cnt, cluster,
                total_queries[t]))

        
        # Whether this template has "arrived" yet?
        if new_ass[t] == -1 and len(list(data[t].irange(current_date, next_date))) == 0:
            continue

        # whether this template is similar to the center of an existing cluster
        new_cluster = None
        if USE_KNN == False or nbrs == None:
            for cluster in centers.keys():
                center = centers[cluster]
                if Similarity(data[t], center, index) > rho:
                    new_cluster = cluster
                    break
        else:
            #print(f"line 265 - calling ExtractSample with x is {data[t]}")
            nbr = nbrs.kneighbors(normalize([ExtractSample(data[t], index)]), return_distance = False)[0][0]
            if Similarity(data[t], centers[clusters[nbr]], index) > rho:
                new_cluster = clusters[nbr]

        if new_cluster != None:
            if new_ass[t] == -1:
                print("%s: template %s joined cluster %d with total %d" % (next_date, cnt,
                    new_cluster, total_queries[t]))
            else:
                print("%s: template %s reassigned to cluster %d with total %d" % (next_date,
                    cnt, new_cluster, total_queries[t]))

            new_ass[t] = new_cluster
            print("line 276 AddtoCenter")
            AddToCenter(centers[new_cluster], min_date, next_date, data[t])
            cluster_sizes[new_cluster] += 1
            continue

        if new_ass[t] == -1:
            #printed next_cluster = 0
            print("%s: template %s created cluster as %d with total %d" % (next_date, cnt,
                next_cluster, total_queries[t]))
        else:
            print("%s: template %s recreated cluster as %d with total %d" % (next_date, cnt,
                next_cluster, total_queries[t]))

        new_ass[t] = next_cluster
        centers[next_cluster] = SortedDict()
        print("Call AddToCenter - line 294")
        AddToCenter(centers[next_cluster], min_date, next_date, data[t])
        cluster_sizes[next_cluster] = 1
        cluster_totals[next_cluster] = 0

        next_cluster += 1

    print(f"line 296 after AdjustCluster for loop - centers is length {len(centers)}")
    clusters = list(centers.keys())
    #print(f"final clusters: {clusters}")
    # a union-find set to track the root cluster for clusters that have been merged
    root = [-1] * len(clusters)

    if USE_KNN:
        print("Building kdtree for cluster merging")

        samples = list()

        for cluster in clusters:
            #print(f"line 311 - calling ExtractSample with x as {centers[cluster]}")
            sample = ExtractSample(centers[cluster], index)
            samples.append(sample)

        if len(samples) <= 1:
            #print("not enough samples again - line 315")
            nbrs = None
        else:
            #print(f"sample length {len(samples)} so normalize")
            normalized_samples = normalize(np.array(samples), copy = False)
            nbrs = NearestNeighbors(n_neighbors=2, algorithm=KNN_ALG, metric='l2')
            #print(f"normalized samples of len {len(normalized_samples)}: {normalized_samples}, nearest neighbors: {nbrs}")
            nbrs.fit(normalized_samples)

        print("Finish building kdtree for cluster merging")

    print("enter for loop - line 331")
    for i in range(len(clusters)):
        c1 = clusters[i]
        c = None

        #print(f"for iteration {i} with c1 as {c1}")
        if USE_KNN == False or nbrs == None:
            #print("no knn or nbrs")
            for j in range(i + 1, len(clusters)):
                c2 = clusters[j]
                #print(f"checking iteration j {j} using c2 as {c2}")
                if Similarity(centers[c1], centers[c2], index) > rho:
                    #print("similarity greater than rho - set c as c2")
                    c = c2
                    break
        else:
            #print(f"line 341 - ExtractSample x as {centers[c1]}")
            nbr = nbrs.kneighbors([ExtractSample(centers[c1], index)], return_distance = False)[0]

            if clusters[nbr[0]] == c1:
                nbr = nbr[1]
            else:
                nbr = nbr[0]

            while root[nbr] != -1:
                nbr = root[nbr]

            if c1 != clusters[nbr] and Similarity(centers[c1], centers[clusters[nbr]], index) > rho:
                c = clusters[nbr]

        if c != None:
            print("line 358 - addtocenter")
            AddToCenter(centers[c], min_date, next_date, centers[c1])
            cluster_sizes[c] += cluster_sizes[c1]

            del centers[c1]
            del cluster_sizes[c1]

            if USE_KNN == True and nbrs != None:
                root[i] = nbr

            for t in data.keys():
                if new_ass[t] == c1:
                    new_ass[t] = c
                    print("%d assigned to %d with total %d" % (c1, c, total_queries[t]))

            print("%s: cluster %d merged into cluster %d" % (next_date, c1, c))

    return new_ass, next_cluster


def OnlineClustering(min_date, max_date, data, total_queries, rho):
    print(rho)
    cluster_gap = 1440

    n = (max_date - min_date).seconds // 60 + (max_date - min_date).days * 1440 + 1 
    num_gaps = n // cluster_gap

    centers = dict()
    cluster_totals = dict()
    cluster_sizes = dict()

    assignments = []
    ass = dict()
    for t in data.keys():
        ass[t] = -1
    assignments.append((min_date, ass))

    current_date = min_date
    next_cluster = 0

    #print statement has nothign
    print(f"line 398 - before OnlineClustering For loop - centers is {centers}, cluster_totals {cluster_totals}, cluster_sizes {cluster_sizes}")
    for i in range(num_gaps):
        next_date = current_date + dt.timedelta(minutes = cluster_gap)
        # Calculate similarities based on arrival rates up to the past month
        month_min_date = max(min_date, next_date - dt.timedelta(days = 30))
        #print(f"for loop iteration {i}, next date: {next_date}, month_min_date: {month_min_date}")

        #first call - nothing. then progressively gets filled in subsequent calls
        print(f"line 405 Call AdjustCluster - with centers length{len(centers)}\ncluster total length {len(cluster_totals)}\ntotal queries {total_queries}\ndata length {len(data)} cluster_sizes length{len(cluster_sizes)}")
        assign, next_cluster = AdjustCluster(month_min_date, current_date, next_date, data, assignments[-1][1],
                next_cluster, centers, cluster_totals, total_queries, cluster_sizes, rho)
        print("exited AdjustCluster - back in line 407 OnlineClustering")
        print(f"line 408 - AdjustCluster returned result to OnlineClustering: new_ass as assign: {assign}, next_cluster {next_cluster}")
        assignments.append((next_date, assign))
        print(f"append next date {next_date} and assign")

        current_date = next_date


    print("line 398 - OnlineClustering Finished")
    return next_cluster, assignments, cluster_totals


# ==============================================
# main
# ==============================================
if __name__ == '__main__':
    print("Starting clustering main")
    aparser = argparse.ArgumentParser(description='Time series clusreting')
    aparser.add_argument('--dir', default="combined-results", help='The directory that contains the time series'
            'csv files')
    aparser.add_argument('--project', default="tiramisu", help='The name of the workload')
    aparser.add_argument('--rho', default=0.8, help='The threshold to determine'
        'whether a query template belongs to a cluster')
    args = vars(aparser.parse_args())

    print(f"Checking output directory: {OUTPUT_DIR}")
    if not os.path.exists(OUTPUT_DIR):
        print("path not exist so creating")
        os.makedirs(OUTPUT_DIR)

    print("entering load data")
    min_date, max_date, data, total_queries, templates = LoadData(args['dir'])

    print("Main method: Entering OnlineClustering")
    num_clusters, assignment_dict, cluster_totals = OnlineClustering(min_date, max_date, data,
            total_queries, float(args['rho']))
    print("Main Method: finished OnlineClustering")
    #print(f"LoadData Returned: min_date: {min_date}\nmax_date: {max_date}\ndata: {data}\ntotal queries: {total_queries}\ntemplates: {templates}")
    with open(OUTPUT_DIR + "{}-{}-assignments.pickle".format(args['project'], args['rho']),
            'wb') as f:  # Python 3: open(..., 'wb')
        pickle.dump((num_clusters, assignment_dict, cluster_totals), f)

    print("Number of clusters:")
    print(num_clusters)
    print("Cluster totals:")
    print(cluster_totals)
    print("Sum of cluster total values:")
    print(sum(cluster_totals.values()))
    print("Sum of total query values:")
    print(sum(total_queries.values()))

    # Container testing/debugging
    #while True:
    #    time.sleep(1)
