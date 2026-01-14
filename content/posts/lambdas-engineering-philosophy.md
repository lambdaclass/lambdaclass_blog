+++
title = "Lambda’s engineering philosophy"
date = 2023-09-27
slug = "lambdas-engineering-philosophy"

[extra]
feature_image = "/images/2025/12/Last_Judgement_by_Michelangelo.jpg"
authors = ["LambdaClass"]
+++

## What makes Lambda different

We often hear that Lambda has a different way of operating compared with other companies. Many people we’ve worked with have praised the speed and quality of our delivery. We attribute that to a set of principles that anyone can apply, and might benefit others. It can be summed up as: observe, iterate, simplify, have a close relationship with your code both in its static and dynamic form, and incorporate process at the correct times to serve the needs of engineering and not management. Let’s break this down:

## Be curious, be attached to learning and solving

We promote a culture where engineers can feel the joy of putting things into production and applying their skills to interesting challenges.

## Observe and Measure

Engineering is applying knowledge to solve problems under a given cost/benefit tradeoff. You cannot solve a problem you cannot see. Seeing is measuring. Use your tools to diagnose the problem, have a metric for success, then measure again after applying your solution.

Build observability into your system. The sooner you see, the sooner you can react, to both changing requirements and changing metrics.

This also applies to performance engineering. Optimization is premature (thus evil) only when it occurs before it is a requirement and before measuring.

Iterate frequently in your perceive-act loop to shorten feedback.

## Speak openly about engineering problems

Once a problem has been identified, speak openly about it. Of course _how_ one communicates is all important when talking to other humans, but if framed correctly a technical discussion should not offend anyone, as the merits or faults of any technical solution only reflect on the thing itself, and not the value of the human or group implementing it.

The earlier a problem (or solution) is communicated and discussed, the better the final solution will be, the lower the risk and cost.

“Pride is not the opposite of shame, but its source. True humility is the only antidote to shame.”

## Relationship with complexity (or lack thereof)

If there is one mantra we repeat and can apply in any context, it is KISS, Keep It Simple, Silly.  
Much has been written about this, and there are echoes of it in many other wise reflections, such as Joe Armstrong’s famous quote _“Make it work, then make it beautiful, then if you really, really have to, make it fast. 90% of the time, if you make it beautiful, it will already be fast. So really, just make it beautiful!”_ ; or in some of the tenets of the Zen of Python:
    
    Beautiful is better than ugly.
      Explicit is better than implicit.
      Simple is better than complex.
      Complex is better than complicated.
      Flat is better than nested.
      Sparse is better than dense.
      Readability counts.
    

Such general maxims are something that may seem truisms, or tautological sometimes. Their value is in keeping them constantly in mind and asking “how does this apply _in this context_?”.

## Dogfooding

Repositories should build easily and cleanly on all of the target environments. A newcomer to the project should be able to set it up with no hassle. Take pride in having an up-to-date readme that people can follow and have your code working on their machine in no time. Open-source as much as you can. Put your code out into the world.

Developers should be hands-on about infra, not only familiar with the usual tooling for development but also with the pipelines and code which puts it into production. Your pipelines should be clean and as observable and debuggable as the product code.

## Generalization should be end game

Do not generalize until you absolutely need it. Repeating code two or three times can be fine. Solve the problem you need to solve, don’t get tangled up in how to abstract or generalize the solution, just get it done in the simplest way possible. Generalizations and abstractions arise naturally with time.

Most new challenging projects usually have two different phases:

### First few weeks: experiment and prototype

Things are just starting out. The problem being solved is not yet well understood, there’s a lot of uncertainty; some people know just enough about the problem to recognize it’s a difficult task, but not enough to go ahead and tackle it. This creates a lot of anxiety around how things should be done and what the best way forward is; endless debates that go nowhere ensue. Sometimes some knowledge is worse than knowing nothing at all.

Getting through this requires recognizing that you don’t fully know how to do things and that’s fine; you have to figure it out through trial and error. The mantra here is _Go fast, try things out, fail quickly, figure it out_.

Introducing a lot of process at this stage is counter-productive, you can’t make a gantt and plan things out with deadlines when you’re not even sure what it is you are building. Doing so just slows you down, or set you on the wrong path.

Morale at this stage is also very important; people are anxious that the project might not pan out, that the problem is not solvable. If there’s too much time without any update or any sort of progress, they get demoralized. The antidote is quickly coding something that performs some basic form of the final desired behavior, and each passing week should expand and improve upon functionality. Don’t let weeks pass by creating lots of code that still doesn’t perform a basic function. Showing regular updates, merging changes quickly and trying them out, deploying regularly and all around having a fast feedback loop is essential to keep people excited and focused.

### Settling down

After a few weeks of work, the project begins to take shape, the problem is better understood and the solution is working out well. People start developing a common vocabulary around the project, they know what problem needs to be solved next and how to do it. Anxiety wears off.

At this point, two things become important:

        * Organizing the work that’s yet to come. The project is no more than a prototype right now, and there is a ton of work to be done to make it production ready.
        * Documenting the progress so far. A lot of knowledge was accumulated in the first few weeks/months of work as ideas were tried out and discarded. It’s important for it not to get lost.

Solving these issues (especially the first one) requires introducing _process_. Writing down all the tasks left, making a gantt, defining milestones and distributing work accordingly are now necessary to continue. The main obstacle is not so much uncertainty anymore, but rather correct planning and execution.

As the project continues to take shape and grow, merging new changes becomes more and more difficult; its complexity starts making it impossible for you to know every nook and cranny. Also, breaking things has a higher cost both in development time and perhaps money if you’re in production. Thorough testing and code review thus become key.

Process is the sign of a _mature_ project. It is very important, but it should not be introduced before it’s necessary.

### Back and forth

Most projects go through these phases more than once. In general, any time a project gets a new requirement that involves a challenging task, a part of it has to revert to the experimentation phase.

The key here is _uncertainty_. When you detect that a given task is hard and people are spending way too much time arguing about how to solve it, without ever trying things out (for fear of breaking things or making the wrong move) you need to revert back to the first phase. This doesn’t mean throwing all the process out the window; people who are working on other regular tasks can continue as usual. It’s just the part of the team tackling this new challenge that needs to change its approach.

## Incorporating process

Of all the infinite process management tools and diagrams under the sun, the one we find most useful is the Gantt chart.  
Here is an outline of how we go about making one, once the project requires it.

        1. Understand what areas there are in the project in a very broad way. E.g. networking, state transitions, api, db, external services, infra. Architecture diagrams might help at this stage.
        2. Divide areas into tasks.
        3. Repeat step 2 a couple of times. This refining will help direct research and prevent the “I want to know everything before coding”.
        4. Research doesn’t mean just reading, this is a good stage to start with some very small PoCs of things you don’t understand. Some PoCs can even be a good task to delegate to other team members while still figuring out tasks. You’ll need to review those in depth later on though.
        5. Track dependencies between tasks. A dependency graph might be a good output here.
        6. Use the dependencies to prioritize (order), and group tasks in vertical slices. These are E2E integrations that provide some high-level feature and usually include a bit of all areas.
        7. The first vertical slice should be bare bones, maybe providing a dumb useless feature, but should give you “something” working. It should have a db, api, networking, ci, testing and linting (and other tools if necessary). This will force you to forever be in a production mindset from day 1 and avoid giant integrations later on. It also forces you to start doing PoCs of different tools early to reduce uncertainty and unblock as many independent paths as possible for next slices.
        8. Make a release plan using these slices. Roughly estimate a number of weeks for each. This is not the time for precise estimations. Also, multiply that number by 1.5 or 2 depending on how optimist you tend to be and how little you still know about the project.
        9. Now you can make a Gantt reflecting the release plan and according to the amount of people you have.
