---
title: "Goodbye Wordpress"
pubDate: "2025-02-16"
categories:
  - "it"
tags:
  - "Wordpress"
  - "Astro"
heroImage: "/new-blog-header.png"
description: "Describing the next iteration in my personal blog's life as it moves from IaaS hosted Wordpress site to an Azure Static Web App with the infrastructure deployed through Terraform; all content hosted in Github and deployed via CI/CD pipelines in Github Actions"
---

This blog has existed in a few different formats since its original inception back when I left university in 2006. For ths most part however it has been based upon the [Wordpress](https://wordpress.org) platform and hosted initially with a friend at [Loho](https://loho.co.uk) before I started to explore building Infrastructure services myself and getting started with [Microsoft Azure](https://azure.microsoft.com).

# Wordpress evolution from IaaS to PaaS

When I moved the website hosting off the Loho cPanel instances into Azure i did what most amateur developers do; build an IaaS virtual machine and drop the standard LAMP stack onto the VM and run the components manually. I clicked through the new virtual-machine UI and a few minutes later had an up to date Ubuntu 18.04 virtual machine running all that I needed to move off cPanel. A quick database dump through PHPMyAdmin and a copy of the wordpress directory and I was live on my own infrastructure.

## Adding TLS security using AzureDevOps

I continued and the website sat running on the Azure VM with MySQL, Apache and PHP providing the underlying software components. The only major change was the introduction of [LetsEncrypt](https://letsencrypt.org/) to provide a TLS certificate to provide a layer of security over the blog's content. The certificates from LetsEncrypt are naturally short lived so I needed a way to request, verify and deploy a certificate to my webserver. After some research online [Automating certificate management with Azure and Let’s Encrypt](https://medium.com/@brentrobinson5/automating-certificate-management-with-azure-and-lets-encrypt-fee6729e2b78) gave me a solution to request the certificate before it expired so I set about recreating the Azure DevOps project to:

1. Run some PowerShell scripts to generate the certificate request using PoSh ACME
2. Request the certificate from LetsEncrypt and store the valid certificate in an Azure Keyvault
3. Use the Azure Linux VM Extension to pull the latest version of the certificate from Keyvault and store it on the virtual machine

The result; an automated certificate renewal and rollover for my web server.

## Moving components off the Virtual Machine

My hosting of websites increased; I was the web host for my brother's business website [Object Atelier](https://objectatelier.co.uk) so I built a new VM, deployed some more LAMP and he had a website running. He benefited from the same LetsEncrypt security that I had built for my own site but the resource costs of running two virtual machines wasn't making sense. I looked to run both web services off a single virtual machine however I had some issues with Wordpress Multisite and the design agency working on his website were keen to have autonomy over the business site.

The next stage was to abstract the database components to [Azure Database for MySQL](https://azure.microsoft.com/en-gb/products/mysql) again this was built through click-ops.. I only needed one instance so why bother defining it all as code. The databases were moved and the virtual machines downsized to be more cost effective and the sites continued to function quite happily.

I used [Azure Front Door](https://azure.microsoft.com/en-gb/products/frontdoor) briefly to act as a Web Application Firewall between the Internet and the website but the costs really didn't stack up for what I was doing and my Azure bills went through the roof so this was removed in favour of some more stringent Network Security Group (NSG) rules and a Wordpress plugin [WordFence](https://www.wordfence.com/) that offered some protection from the spam IPs that would hit the sites.

## Wordpress as a service

My websites were running fine, they worked and didn't need much feeding or watering (Azure Update Manager would patch and reboot them weekly) but as I prepared to get married in 2023 I suddenly had a new reason for a website. Our wedding guests may be interested in my technology blogs but my wife and I wanted something a bit more focussed to describe our big day and to share news from our Honeymoon.

I decided that building a third virtual machine didn't make any sense and now that all the VMs were doing was running Apache and PHP it seemed more sensible to run these as an Azure App Service instead. Luckily Microsoft had published some content specifically around running Wordpress as an App Service and with a quick-start guide you would have the latest and greatest Wordpress deployment running in an entirely Platform-as-a-Service (PaaS) environment.

![An image of the Azure Architecture deployed to support Wordpress running in an App Service Plan](/wordpress-app-service.png "Wordpress App Service architecture")

The wizard was again point and click and gave you all the component parts you needed however I already had a MySQL database running with more than enough capacity so when the wizard was done I moved the databases to my existing instance and removed the extra resources.

My brother's website moved across easily however the age of the PHP binaries delivered and supported on Ubuntu 18.04 were not playing nicely when I tried to repoint an App Service Plan at my Wordpress database.

# Learning Infrastructure as Code

In the running of the Wordpress sites it had all been manual point, click and run the services manually. It worked for the small scale interactions that I was doing once in a while and I didn't really see the need to define my resources "as code".

When i started my current job however I was now working with some brilliant technical teams who **ONLY** lived in the IaC world. Anyone who was pointing and clicking in the AWS or Azure console was simply "doing it wrong" and whilst my job didn't necessitate working on cloud hosting directly I wanted to understand what the fuss was all about.

The teams I was working around all loved [Terraform](https://www.terraform.io/) as they could easily define their services and would favour short-lived application services over building virtual machines and deploying code into them. I could still understand code that people had written but a lot of the work the teams did confused me referencing modules and different code for live and non-live systems however I could see that by defining the infrastructure in this way it could be built and rebuilt the same across multiple environments eliminating the risk of human error between non-live and live.

I set about looking at how I could bring Terraform into what I did to support my personal projects and rather than mess with my click-ops website hosting I started to build some terraform to replicate this. My starting point was to try and use the Microsoft provided Github repository that stood up the [Wordpress PaaS offering](https://github.com/Azure/wordpress-linux-appservice) and make this work for my multiple websites.

Conscious of costs I started to play with the code in AzureDevOps and built a pipeline to deploy the web service using Terraform and then automatically destroy the code after six hours as I knew I could run up a sizeable bill for resources that were deployed but never used.

## Publishing a Terraform module

Playing with Terraform was going well and I knew my way around the basics of the language and my build, test, break approach was working. One Christmas I was working on a project to implement [MTA-STS](https://www.ncsc.gov.uk/collection/email-security-and-anti-spoofing/using-mta-sts-to-protect-the-privacy-of-your-emails) across our work mail domains and I saw the NCSC had published a [Terraform module](https://github.com/ukncsc/terraform-aws-mtasts) in Github to publish the MTA-STS resources using AWS [Route 53](https://aws.amazon.com/route53/) and [S3 Buckets](https://aws.amazon.com/s3/) there wasn't a similar option for Microsoft Azure.

Using my spare time I created my own Github repository and set about building similar code but using Azure Storage Accounts and the Static Website capability as well as a CDN endpoint and custom domain to link the records back to the relevant domain that was being protected.

The repository took on a similar name to the NCSC's and is published and still available via my personal Github account [terraform-azure-mtasts](https://github.com/MattWhite-personal/terraform-azure-mtasts). I had done a thing, the code worked and created the relevant resources and whilst I'm sure nobody but me has ever used this I felt that I had achieved in making something that can be built and deployed as code.

## DNS as Code

So I have a repository that lets people build MTA-STS records for their domains, what if I could manage more DNS records as code? I again borrowed some inspiration from work colleagues and the way that our ops-engineering team managed the multitude of domains we have registered to support the organisation.

My use case is much smaller, I think I look after seven or eight Domains for family members. I had already hosted most of them in Azure so why not put my new Terraform skills to good use and define the Domains as code? [dns-iac](https://github.com/MattWhite-personal/dns-iac) was born.

To keep this post somewhat on point I will not go into the details on how the repository and code works but it supports the creation and management of DNS records of all types in Azure.

# Getting rid of Wordpress

Back on topic of how to retire Wordpress I had a look at some of my colleagues personal websites and was surprised to see that traditional LAMP blog is less of a thing. Smaller, lighter services written using [Markdown](https://en.wikipedia.org/wiki/Markdown) and then building static HTML pages seems to be the order of the day. It's faster, simpler and harks back to writing my first ever web pages in the late 1990s where I would religiously type in Notepad or similar

```html
<html>
  <head>
    <title>Matt's Webpage</title>
  </head>
  <body>
    <center><h1>Matt's New Webpage</h1></center>
    <p>Some content would go in here</p>
    <p>I would create more paragraphs</p>
    <h2>This is a list</h2>
    <p>
      <ul>
        <li>With some lists I</li>
        <li>would describe things</li>
        <li>and they would render in a web browser</li>
      </ul>
    </p>
  </body>
</html>
```

## Looking for Wordpress Alternatives

Looking around the Internet I found a few static site generators that built HTML content based upon Markdown and quickly found [Astro](https://astro.build/). They had a really nice getting started tutorial to get used to the components and build a very simplistic blog site with sample content. I went through the tutorial and the output of that is currently published on an Azure [Static Web App](https://azure.microsoft.com/en-gb/products/app-service/static) and can be viewed [here](https://tfttest.matthewjwhite.co.uk/).

I understood the language and felt that I could make this work so the next stage was to look at how do I take all the content that sits in Wordpress in that database going back years, most of it is irrelevant and not needed, and put it into an Astro site. Thankfully the Astro team has a [guide for that](https://docs.astro.build/en/guides/migrate-to-astro/from-wordpress/) so I grabbed the content and generated the Markdown files for each post.

I looked over the pages and decided that whilst most of the content may now be obsolete the technical posts I wrote as part of previous jobs were possibly still of value so recreated them within Astro.

One challenge I had was that the current blog posts were using a date based permalink `https://matthewjwhite.co.uk/<year>/<month>/<day>/<title>` that Astro didn't support out of the box. A quick Google found [Tom Spencer's blog](https://www.tomspencer.dev/blog/2023/12/05/date-based-urls-with-astro/) where he had been on a similar journey. Rather than reinvent the wheel I leveraged his code and tweaked it slightly for my URL pattern.

I translated the categories and tags capability in the Astro build a blog example to render a page for each category or tag from the old posts.

## Automating the build and updates

Bringing all of this together I now have multiple parts of learning that has taken me from IaaS to full PaaS:

- Deploy the infrastructure to support the new website - [web-hosting](https://github.com/MattWhite-personal/web-hosting) _This is currently a private repo but will become public_
- Managing DNS records as code and using remote-state to separate projects - [dns-iac](https://github.com/MattWhite-personal/dns-iac)
- Build and deploy the Astro content onto Azure Static Web App - [matthewjwhite.co.uk](https://github.com/MattWhite-personal/matthewjwhite.co.uk)

To keep these up to date and ensure that vulnerabilities are well managed I now use [Dependabot](https://github.com/dependabot) to scan for updates to Astro and Terraform and I use [Checkov](https://www.checkov.io/) to scan the Terraform code for misconfigured resources that are a potential security risk. The activity to run the updates are now all handled by [Github Actions](https://github.com/features/actions) so there is no manual deployment of technology.

# Finishing this off

This blog represents the cutover of services from Wordpress to Astro. There are certain things that have not come across and I still have work to do but I needed to take the plunge and launch the new site.

- I am using Github [Issues](https://github.com/MattWhite-personal/matthewjwhite.co.uk/issues) to call out items that need to be added.
- I have decided that I will drop the Comments for the current blog however I am considering if using Github Discussions I can render future comments and conversations on technical docs
- I still need to rewrite my About Me page; the current page is outdated and the lorem ipsum dolor page will do for now
- I need to look at Google Analytics and Search Engine discoverability of the live site

# Final thoughts

This has been a long time coming. The date of this post compared to the previous post five and a half years apart shows how regularly I write. I don't know if this will make me more creative or not **but** I do now have a more lightweight and streamlined service that can be kept up to date easily and without a lot of click-ops!

## Links to colleagues personal websites

Thank you to current and former colleagues who have built similar websites and have been an inspiration for me going on this journey.

- [John Nolan](https://www.johnnolan.dev/)
- [Dean Longstaff](https://deanlongstaff.com/)
- [Richard Baguley](https://richardbaguley.com/)
