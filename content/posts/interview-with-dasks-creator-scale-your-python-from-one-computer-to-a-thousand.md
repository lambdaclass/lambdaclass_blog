+++
title = "Interview with Dask’s creator: Scale your Python from one computer to a thousand"
date = 2019-09-03
slug = "interview-with-dasks-creator-scale-your-python-from-one-computer-to-a-thousand"
description = "My love for building distributed systems with Erlang, databases and fetching huge volumes of data still lives on. But nowadays I want to…"

[extra]
feature_image = "/content/images/2025/12/Screenshot-2025-12-19-at-12.18.43---PM.png"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Data Science", "Distributed Systems", "Python"]
+++

My love for building distributed systems with Erlang, databases and fetching huge volumes of data still lives on. But nowadays I want to have better theoretical and practical tools to understand the data. That is why I have been seriously studying probability, statistics and getting better at Python, numpy, pandas, scikit-learn, scipy and R. If you have read my earlier interviews you are probably aware of this.

That is why I decided to interview Dask’s creator Matthew Rocklin. Dask is a great bridge between the two areas that we specialize at my company [LambdaClass](https://lambdaclass.com/): distributed systems and data science. Dask is a great tool to parallelize python libraries. When you have some spare time I highly recommend that you check its code. Meanwhile I leave you with Matthew’s answers.

* * *

**What is Dask? Why did you create it?**

Dask is a Python library designed to parallelize other common Python libraries, like NumPy, Pandas, Scikit-Learn and others. It helps people use Python on either a single multi-core machine, or a large distributed cluster.

People tend to use it either as a “Big Pandas” or “Big NumPy”, or as a lower level library to build their own parallel systems.

Originally we created Dask to parallelize Numpy and Pandas. We quickly found that the internals of Dask were useful for many more things, so we quickly pivoted to exposing the internals as a generic parallel system.

**Dask dataframes are a full replacement of pandas dataframes?**

No, the Pandas API is **huge** , so a full replacement is nearly impossible.

That being said, Dask Dataframe does implement the vast majority of popularly used Pandas functionality. Common staples like elementwise, reductions, groupbys, joins, rolling, timeseries, and more operations are all there. Additionally, because Dask dataframes are just a bunch of Pandas dataframes spread around a cluster it’s often pretty easy to convert custom code from Pandas to Dask easily.

It’s also worth noting that Dask != Dask Dataframes. Dataframes only account  
for about a third of Dask use out there. Dask goes way beyond just  
parallelizing Pandas.

**Is there any downside of using Dask dataframes instead of pandas dataframes?**

Oh definitely. If Pandas is solving your problem today, please don’t switch to Dask.

As with any distributed system, Dask adds a lot of complexity like network  
overheads, function serialization, and longer tracebacks in errors. We do a  
lot of work to keep our overhead small, both by keeping Dask lightweight and  
taking care of Python usability, but still, if you don’t need to switch, then  
don’t.

**How is it different form other distributed computation solutions (eg Hadoop MapReduce, Spark, Storm, Luigi, Airflow)?**

Dask is a bit lower level and more generic than those systems, and so can be used to build up similar solutions using existing Python libraries.

For example:

  * When we combine Dask with Pandas we get [Dask Dataframes](https://docs.dask.org/en/latest/dataframe.html), which are comparable with Spark DataFrames
  * When we combine Dask with Scikit-Learn we get [Dask-ML](https://ml.dask.org)
  * When we combine Dask with Python’s [futures or async/await](https://docs.dask.org/en/latest/futures.html) APIs we get a real-time framework, somewhat similar to Storm
  * When we combine Dask with _cron_ like logic, we get an ETL framework like Airflow or Luigi. In fact, some of the Airflow developers split off and made [Prefect](https://www.prefect.io/) a successor to Airflow which delegates the execution and data movement to Dask

Additionally, Dask can be combined with other libraries to get novel systems  
that aren’t in your list. For example:

  * When we combine Dask with Numpy we get a scalable multi-dimensional [Dask Arrays](https://docs.dask.org/en/latest/array.html).
  * When we combine Dask with GPU-accelerated Pandas or Numpy like libraries like [RAPIDS](https://rapids.ai) we get distributed GPU-accelerated dataframes and arrays.

Internally, Dask has the scalability of a system like MapReduce or Spark, with  
the flexibility of a system like Luigi or Airflow. This combination is nice both when you’re building new systems, and means that Dask gets used in a ton of novel work.

**How does data locality affect the performance of Dask? Does it assume all data is local to workers?**

By data locality you might mean two things (both of which Dask handles well):

1\. Where does the data live in some storage system, like S3 or HDFS?

Dask is more than happy to query a data-local storage system like HDFS,  
find out where all the data lives, and target computations appropriately.

However, this kind of workload is becoming increasingly rare. More often  
people are using storage systems that prefer global accessibility over data  
locality, so this matters less and less these days in practice.

2\. Once data is in memory, can Dask avoid moving it around?

Dask thinks a lot about where to run computations, and avoiding needless  
data communication is a big part of this decision. Sometimes we do need to  
move data around, but yes, Dask certainly avoids this when possible.

Moreover, because Dask gets used with a **wide** variety of workloads, our  
scheduling heuristics have had to evolve quite a bit over the years. It’s very  
rare for us to find problems today on which Dask’s data locality heuristics  
don’t respond optimally.

**What is the biggest Dask cluster you have seen in production?**

One thousand Windows machines.

Dask gets used on some of the world’s largest super-computers (I was  
logged into [Summit](https://www.olcf.ornl.gov/summit), the worlds largest super computer, just a few hours ago), and is deployed routinely on all major clouds.

However, Dask also scales down nicely. You can also just _import dask_ and run it on a thread pool in a single python process or Jupyter notebook. As we like to say, _“The median cluster size is one”_. Dask is pure-Python, and super-lightweight if it needs to be. You can just `pip install dask` and it ships with the popular Anaconda distribution, which is deployed on millions of machines around the world.

**The Dask scheduler and Dask worker architecture, implementation and protocol was inspired by any other project?**

The central scheduler + distributed worker architecture is pretty common today. It’s a pragmatic choice for systems that want to scale between 1–1000 nodes.

So sure, Dask was inspired by other projects. All of them :). Notably, Dask tries hard not to reinvent too much. We rely a ton on other infrastructure within the Python ecosystem. We use Tornado and asyncio for concurrency and peer-to-peer networking, Numpy, Pandas, and Scikit-learn for computation, and other Python APIs like concurrent.futures and joblib for user APIs.

Dask is really just a smashing together of Python’s networking stack with its  
data science stack. Most of the work was already done by the time we got here.

**Which do are for you the most interesting frameworks, tools or libraries implemented on top of Dask and why?**

I’ll list a few interesting frameworks, but there are a ton out there these days:

  * [Xarray](https://xarray.pydata.org) is a library commonly used to study Earth system data, like the climate, meteorology, oceanography, satellite imagery, and more. It’s really gratifying to see people use Dask to finally be able to analyze these huge climate science simulations, and help us better understand the planet.
  * [Prefect](https://prefect.io) provides a bunch of niceties on top of Dask for common Data Engineering or ETL workloads, similar to Airflow/Luigi. We got these feature requests constantly when we were starting out but declared them out of scope. It was great to have another project come by, take that feature set, and implement it way better than we ever could.
  * [TPot](https://epistasislab.github.io/tpot) is a library for automatic machine learning. You give it a dataset, and it tries out a bunch of models and pre-processors to find a good model. TPot existed well before Dask, and it has really gnarly parallelism internally, which makes it hard for non-experts to accelerate. Fortunately the TPot and Dask developers were able to get this going in a weekend, and now you can scale out this search with Dask on whatever parallel hardware you have.
  * [RAPIDS](https://rapids.ai) is a GPU-accelerated data science stack by NVIDIA. They were building out their own fast GPU implementation of Pandas and Numpy and wanted something to solve the multi-node problem for them. Dask was able to step in, handle all of the distributed communication, scheduling, and load balancing, and then step aside while NVIDIA’s fast GPU algorithms took over. (disclaimer, this is my current employer).

**Could you please tell us about the work you are doing at NVIDIA to offload Dask computations to the GPU?**

Yeah, RAPIDS is really exciting. It turns out that GPUs are good for things other than graphics and deep learning. They’re surprisingly effective at accelerating more traditional computing in data science (and actual science). Operations like dataframe joins, CSV parsing, FFTs, text processing, and more can often be accelerated 10x-200x. Historically you had to know C and CUDA to use these libraries though, which made them accessible only to somewhat experience software developers.

The RAPIDS project within NVIDIA is wrapping up all of these algorithms in Python, and exposing APIs to data science users that look like drop-in replacements for Numpy/Pandas/Scikit-Learn.

They use Dask to provide multi-GPU parallelism (some people have many GPUs in a single machine) and multi-node parallelism across a cluster. Dask’s  
flexibility, and the fact that it’s pretty unopinionated about what you run as  
computation make it the perfect fit. It’s also one of the only task schedulers  
out there that run in a non-JVM language, which helps if you use natively  
compiled code, like CUDA.

**Do you have any book, MOOC or resource that you would recommend to those of us that want to learn more about the implementation of schedulers, concurrency models and distributed systems?**

Ha! Sadly no.

Centrally managed distributed schedulers are, unfortunately, not a common topic of research these days. From an academic/intellectual level it’s a fairly  
simple problem. Most of the difficult parts are in the details of engineering,  
which are unfortunately not that interesting to anyone who isn’t building a  
distributed scheduler.
