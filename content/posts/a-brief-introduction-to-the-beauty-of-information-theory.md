+++
title = "A brief introduction to the beauty of Information Theory"
date = 2020-05-06
slug = "a-brief-introduction-to-the-beauty-of-information-theory"
description = "Or how to be a hardcore Guess Who gamer"

[extra]
feature_image = "/content/images/2025/12/Screenshot-2025-12-19-at-12.10.48---PM.png"
authors = ["LambdaClass"]

[taxonomies]
tags = ["Math", "Statistics", "Data Science", "Information Theory", "Decision Tree"]
+++

#### Or how to be a hardcore Guess Who gamer

 _Authors: Juan Pablo Amoroso, Javier Rodríguez Chatruc, Camilo Plata, and Federico Carrone._

> The fundamental problem of communication is that of reproducing at one point either exactly or approximately a message selected at another point.  
>  — Claude Shannon, 1948

Imagine you were tasked with designing a comunications system between a space station and a ground control headquarters back in Earth. The system would transmit and receive messages encoded in binary, that is, as a sequence of 1s and 0s. As the message travels, there may be interferences from other radio signals, so that what is picked up in ground control is not exactly the same as the original message. Under these circumstances, is it possible to devise a scheme that allows reliable comunication?

A simple workaround would be to add redundancy: send each bit a number of times, let’s say 5:
    
    
    11111
    00000
    …

If ground control receives the message _11101_ , they could be fairly certain that what was truly sent was _11111_. Although this simple system would work (up to a point), we can see that it is very wasteful: we have to send 4 extra bits for every bit in the original message. The _transmission rate_ is therefore only 20%. Can we do any better?

There seems to be a dilemma here: if we want accuracy, we must lower the rate of transmission.

This is the problem Claude Shannon tackled in his 1948 paper _A Mathematical Theory of Communication_. In it, he proved that there is a limit for the rate of information that can be reliably transmitted over a noisy channel (the _Shannon limit_). However, below this limit we can transmit information with an increasingly small error. This important result tells us that there _exists_ a code that allows arbitrary accuracy over a given comunication channel, but it does not tell us how to build it.

More precisely, let’s say a channel has a probability _p_ of transmitting a bit correctly, and a corresponding probability of 1 —  _p_ of sending the wrong bit, Shannon proved that the optimum rate of transmission is:

![](/content/images/max/2000/1-kCNAUFlhWJv1kUzKatqINA.png)![](/content/images/max/2000/1-TgCse1znfuWYULYwXeo4Aw.png)

The plot is symmetrical around _p = 0.5_ , with maxima at _p = 0_ and _p = 1_. The case of _p = 0_ is interesting, the channel has perfect noise: it flips all the bits in the original message. But if we know that, then the message is trivially deciphered, we just flip them back.

The formula is commonly stated in terms of [information entropy](https://en.wikipedia.org/wiki/Entropy_%28information_theory%29), a measure Shannon devised that can be interpreted as the level of ‘uncertainty’ or ‘surprise’ associated with the channel.

![](/content/images/max/2000/1-fCyO-nZidJEiOqwqDGWJ3g.png)![](/content/images/max/2000/1-s0z3MUCTtJvh_AsvxGg72g.png)

We can see that the entropy has a maximum at 1 when _p_ = ½, and minima at 0 for _p =_ 0 and _p =_ 1.

More generally, given a random message _M_ that can take _n_ different values with probability _pᵢ_ for _i =_ 1,…,_n_ , we define the entropy of the message as:

![](/content/images/max/2000/1-ezweLprVK1INseQwDCN2yg.png)

#### Guess Who example

Let’s take a different approach. Suppose you are playing _Guess Who_ , the game where you ask yes/no questions about the appearance of your opponent’s character in order to single him or her out among a set of characters. You ask yourself: what order should I ask the questions in to maximise the probability of winning? Intutively, you try to ask first about features most of the characters have.

![](/content/images/max/2000/1-TkW9quvg52IBgM06fM-7IA.jpeg)Hardcore Guess Who gamers apply Information Theory for optimal results

Moreover, an optimal question is one that divides the population evenly, that is, one that regardless of the answer (_yes_ or _no_) discards half the characters. In any other case, you are not gaining the optimal amount of information with each question.

But what if you can’t divide the characters evenly by their characteristics? To answer the question, first we recall the concept of entropy defined above. We can think of a question as a variable _X_ that splits the population into groups _xᵢ_ with probabilities _pᵢ_. For example, think of a question about the eye color of the character (the questions in the game are technically only _yes_ or _no_ but this can be generalized). With this in mind, the entropy of a question becomes:

![](/content/images/max/2000/1-KZq1CO03SyEnsH0qLamzRQ.png)

The intuition here is that with each possible answer, we gain an amount of information  _— log_ _p_(_x_ ᵢ), meaning that if we receive an answer with a very low probability (i.e. we ask if the character has a feature that is shared by very few people, and the answer is yes), the amount of information we gained is higher than an answer with more probability.

On the other hand, entropy is related to uncertainty. For example, if we flip a coin, the uncertainty in the outcome is higher with a _p_ = 0.5 than with any other value of _p_. And in our case, more uncertainty is better. Why? If we choose a question with an uneven distribution in the population, lets say 0.7 and 0.3, the odds are that our character is among the 70%, discarding with the _no_ answer only the remaining 30%, but with a more even division (and therefore more uncertain), we always tend to discard 50% of the population, leading to an advantage in the long run. This means that the best questions to ask are those that maximize the entropy, i.e, the ones with the higher uncertainty.

#### Decision Trees

One common use of entropy is in decision trees, where one uses a set of features (features that split the data into disjoint sets) to construct a flowchart for a classification problem. Here, a common question is: which order should we “apply” the features in to get the best splits? A possible solution is to recursively always use the feature that maximizes the _information gain_. If we’re working with a dataset _S_ and our feature is called _X_ , the information gained on _S_ by _X_ , _I_(_S_ ,_X_), is calculated as:

![](/content/images/max/2000/1-tIzlfBpMihRvpfZICpWZJA.png)

where _H_(_S_ |_X_) is the conditional entropy of _S_ given _X_. Intuitively, this is just the reduction in the entropy of the dataset _S_ if we know _X_. Thus, it makes sense to choose the features _X_ that maximize this value, as they will be the ones that reduce uncertainty the most, effectively obtaining the best splits.

Algorithms that consider the information gain at each node to choose the next feature are called _greedy_ algorithms. Such algorithms do not take into account the overall information gain and may lead in some cases to suboptimal queries, but they are well-behaved and have a straightforward approach.

As an example, consider the picture below, where a decision tree method was used on the famous Iris flower dataset and two features were selected, the petal width, first with 0.8 cm as a threshold and then 1.75 cm. Setting aside how these specific features are selected, why use the ≤ 0.8 first? With the information gain calculation we described, we can provide an answer. We will call the feature that separates petal width on 0.8 cm _X_ and the other one _Y_.

![](/content/images/max/2000/1-dEesB-YyIVG81qhIDn_T_w.png)

Applying _X_ first splits the 150 data points (usually one would split between training and test sets, here for simplicity we use the entire set) into two sets: one containing the entire _setosa_ class (50 points, corresponding to ≤ 0.8 cm) and nothing else, and the other containing the rest. In that case the calculations yield:

![](/content/images/max/2000/1-2dDOZS_8PGYonq3RZYoyAg.png)

On the other hand, applying _Y_ first gives us one set with 50 _setosa_ , 49 _versicolor_ and 5 _virginica_ (≤ 1.75 cm) and another with no _setosa_ , 1 _versicolor_ and 45 _virginica_. This leaves us with:

![](/content/images/max/2000/1-VCQsujq_mEufMZi1X4DGdw.png)

Thus the information gain from _X_ (petal width being under or over 0.8 cm) is greater than the one from _Y_ , and we should use it first. This makes sense intuitively, as _X_ completely separates the _setosa_ class from the other two, whereas using _Y_ first gives a more entangled split.

#### Conclusion

It is hard to overstate the importance of Shannon’s work: the Theory of Information has found [many applications](https://www.britannica.com/science/information-theory/Applications-of-information-theory) in fields as diverse as statistical inference and machine learning, natural language processing, genetics, data compression, coding theory, and cryptography. With over 120,000 citations, few papers can boast a similar impact. In the words of information theorist Anthony Ephremides:

> It was like an earthquake and the aftershocks haven’t finished yet!
