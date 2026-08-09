import 'package:flutter/material.dart';

const _cBg = Color(0xFF090D12);
const _cPanel = Color(0xFF0F151C);
const _cPanel2 = Color(0xFF141C25);
const _cLine = Color(0xFF263342);
const _cText = Color(0xFFE8EDF3);
const _cMuted = Color(0xFF8895A5);
const _cBlue = Color(0xFF63A9FF);
const _cAmber = Color(0xFFE2B866);

class ProductEditorialHomeScreen extends StatefulWidget {
  const ProductEditorialHomeScreen({super.key});
  @override
  State<ProductEditorialHomeScreen> createState() => _ProductEditorialHomeScreenState();
}

class _ProductEditorialHomeScreenState extends State<ProductEditorialHomeScreen> {
  String sport = 'Top Stories';
  String query = '';
  static const sports = ['Top Stories','NBA','WNBA','NFL','NHL','MLB','NCAAM','NCAAW','College Football','Tennis','MLS','Premier League','Champions League'];
  static const stories = <(String,String,String,String)>[
    ('NBA','Front offices are rebuilding the meaning of roster flexibility','Cap mechanics, apron restrictions and draft equity now shape every serious transaction conversation.','Analysis'),
    ('NBA','The next generation of two-way wings','A data-led look at usage, shot profile, defensive workload and lineup portability.','Film + Data'),
    ('WNBA','A new era of spacing and pace','How lineup construction and shot selection are changing across the league.','League Trends'),
    ('NFL','Building a contender through positional value','Draft capital, quarterback economics and the roster decisions that compound.','Front Office'),
    ('MLB','Why pitch-shape development keeps accelerating','Organizations are combining biomechanics, tracking and individualized pitch design.','Baseball Lab'),
    ('NHL','The hidden value of transition play','Entry denial, controlled exits and puck movement are reshaping player evaluation.','Analytics'),
    ('NCAAM','The transfer portal changed roster building forever','Continuity, veteran creation and role fit now matter differently in March.','College Basketball'),
    ('NCAAW','The stars driving the next growth cycle','Player development, media and program-building are converging.','College Basketball'),
    ('College Football','The economics of the modern depth chart','Portal movement and player compensation have turned roster planning into year-round operations.','College Football'),
    ('Tennis','What the best returners do differently','Court position, first-step reads and return depth reveal a repeatable edge.','Tennis Lab'),
    ('Premier League','Recruitment models are getting more contextual','Possession value, pressing role and league translation matter more than raw event totals.','Football Analytics'),
    ('Champions League','How elite knockout teams manage game state','Possession, territory and substitution timing change when the margin for error disappears.','Tactics'),
    ('MLS','The roster-rule puzzle behind sustainable contenders','Allocation money, designated players and development pathways reward sophisticated planning.','Front Office'),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = stories.where((s) => (sport == 'Top Stories' || s.$1 == sport) && (query.isEmpty || '${s.$2} ${s.$3} ${s.$1}'.toLowerCase().contains(query.toLowerCase()))).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Hero('SPORTS TERMINAL EDITORIAL','Independent sports journalism built beside the data','Deep reporting, analysis, explainers, front-office intelligence and original voices across every major sport. The editorial product is designed as a premium reading destination rather than a generic article list.'),
      const SizedBox(height: 14),
      _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final s in sports) Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(s), selected: sport == s, onSelected: (_) => setState(() => sport = s)))])),
        const SizedBox(height: 10),
        TextField(onChanged: (v) => setState(() => query = v), style: const TextStyle(color: _cText), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search reporting, analysis, teams, players and topics…', border: OutlineInputBorder())),
      ])),
      const SizedBox(height: 14),
      if (visible.isNotEmpty) _LeadStory(story: visible.first),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 760 ? constraints.maxWidth : constraints.maxWidth < 1150 ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 24) / 3;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final story in visible.skip(1)) SizedBox(width: width, child: _StoryCard(story: story))]);
      }),
      const SizedBox(height: 16),
      const _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle('Editorial system'), SizedBox(height: 8),
        Text('Sections support staff writers, contributors, beats, team pages, player tags, series, newsletters, featured packages, breaking news, long-form analysis, comments, saves, follows, reading history and premium access. Article pages should expose author identity, publication/update timestamps, corrections, related data modules and linked Sports Terminal entities.', style: TextStyle(color: _cMuted, height: 1.55)),
      ])),
    ]);
  }
}

class ProductPlatformLegalScreen extends StatelessWidget {
  const ProductPlatformLegalScreen({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    if (kind == 'about') return const _AboutPage();
    if (kind == 'contact') return const _ContactPage();
    final privacy = kind == 'privacy';
    final sections = privacy ? _privacySections : _termsSections;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Hero(
        privacy ? 'LEGAL / PRIVACY' : 'LEGAL / TERMS',
        privacy ? 'Sports Terminal Privacy Policy' : 'Sports Terminal Terms & Conditions',
        privacy
            ? 'A comprehensive product privacy framework covering account data, sports preferences, community activity, analytics, security, retention, disclosures, user rights and international use.'
            : 'The governing agreement for access to Sports Terminal, including accounts, subscriptions, data, content, community, intellectual property, acceptable use, transactions, disclaimers and dispute terms.',
      ),
      const SizedBox(height: 12),
      _LegalNotice(privacy: privacy),
      const SizedBox(height: 12),
      for (var i = 0; i < sections.length; i++) ...[
        _LegalSection(number: i + 1, title: sections[i].$1, body: sections[i].$2),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 8),
      const _Surface(child: Text('Production legal notice: this in-product draft is deliberately comprehensive, but company name, legal entity, address, governing jurisdiction, privacy contact, DPO/representative information, subscription terms, arbitration mechanics and jurisdiction-specific disclosures must be finalized with qualified counsel before public launch. No product copy can guarantee maximum legal protection in every jurisdiction.', style: TextStyle(color: _cAmber, height: 1.5, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _LegalNotice extends StatelessWidget {
  const _LegalNotice({required this.privacy});
  final bool privacy;
  @override
  Widget build(BuildContext context) => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('EFFECTIVE DATE: [LAUNCH DATE]  ·  LAST UPDATED: [DATE]  ·  VERSION: 1.0', style: TextStyle(color: _cBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
    const SizedBox(height: 8),
    Text(privacy ? 'This Policy applies to Sports Terminal websites, applications, APIs, community features, professional workspaces, content products, communications and related services. It explains what information we collect, why we use it, when we disclose it, how long we retain it, and the choices and rights available to users.' : 'By creating an account, accessing or using Sports Terminal, you agree to these Terms and the Privacy Policy. If you do not agree, you may not create an account or use the Services. Organizations are responsible for ensuring authorized users comply with these Terms.', style: const TextStyle(color: _cText, height: 1.55, fontWeight: FontWeight.w600)),
  ]));
}

const _privacySections = <(String,String)>[
  ('Scope and Controller','Sports Terminal [legal entity placeholder] is the controller of personal information for consumer-facing processing except where an organization customer controls data within an enterprise workspace. This Policy covers visitors, registered users, organization users, authors, community participants, prospective customers, support contacts and other individuals interacting with the Services.'),
  ('Information You Provide','We may collect account identifiers, name, username, email, password credentials or authentication tokens, profile image, biography, location if voluntarily supplied, favorite teams and players, sports interests, notification settings, subscription information, organization and job information, support requests, survey responses, contest entries, legal consents, account-verification information and any other information you choose to submit.'),
  ('Community and User Content','We collect posts, comments, votes, reactions, follows, saves, blocks, mutes, reports, messages, public profile fields, article submissions, drafts, moderation appeals and associated metadata. Public content and public profiles may be visible to other users and may be indexed or shared according to product settings. Private messages are processed to provide messaging, security, abuse prevention and legal compliance.'),
  ('Sports Preferences and Research Activity','We may process favorite teams, favorite players, watchlists, saved searches, viewed player/team/game pages, followed authors, fantasy preferences, research boards, models, workspaces, trade scenarios, notes, alerts and other product interactions to provide personalization, recommendations, continuity and professional workflows.'),
  ('Technical and Device Information','We may collect IP address, device and browser type, operating system, app version, device identifiers, language, approximate location inferred from IP, referral URLs, timestamps, pages and features used, crash logs, performance telemetry, security events, authentication events, cookie or local-storage identifiers and network diagnostics.'),
  ('Payment and Subscription Information','Payment processors may collect payment card or bank details. Sports Terminal may receive billing name, billing address, payment status, subscription tier, invoice data, transaction identifiers, tax information and limited payment-method metadata. We should avoid storing full payment-card numbers unless required and handled under appropriate payment-security controls.'),
  ('Organization and Professional Workspace Data','For team, league, media, agency, investor or other organization accounts, we may process membership, roles, permissions, shared research, internal notes, cases, approvals, files, audit events and collaboration activity. Contract terms may specify whether Sports Terminal acts as controller, processor/service provider, or both for particular data.'),
  ('Data from Third Parties','We may receive identity or authentication data from sign-in providers; billing data from payment processors; sports data from leagues, teams, public records, licensors and data vendors; content metadata from publishing partners; fraud/security signals from vendors; customer-contact data from sales systems; and information users authorize third-party integrations to provide.'),
  ('Cookies, Local Storage and Similar Technologies','We may use necessary cookies and storage for authentication, security, preferences and session continuity; analytics technologies for product measurement; and, where legally permitted and consented to, optional personalization or advertising technologies. Consent controls should distinguish strictly necessary technologies from optional categories and honor applicable opt-out signals.'),
  ('Purposes of Processing','We use information to provide and authenticate the Services; personalize content and research; operate community and messaging; save preferences and workspaces; process subscriptions; provide support; communicate service, security and product updates; measure performance; improve features and models; prevent fraud, abuse and unauthorized access; enforce rules; comply with law; protect rights and safety; and conduct legitimate business operations.'),
  ('Legal Bases Where Applicable','Where laws such as the GDPR or UK GDPR apply, processing may rely on performance of a contract, legitimate interests, consent, compliance with legal obligations, protection of vital interests or other lawful bases. We will identify the applicable basis for material processing and provide consent withdrawal where consent is the basis.'),
  ('Automated Systems and AI','Sports Terminal may use automated systems to rank content, recommend teams/players/articles, identify spam or abusive activity, summarize sports information, assist research and power analytical features. Outputs may be probabilistic and should not be treated as guaranteed facts or professional advice. Where legally required, we will provide disclosures and rights concerning solely automated decisions that produce legal or similarly significant effects.'),
  ('How We Disclose Information','We may disclose information to infrastructure, hosting, analytics, customer-support, communications, security, authentication, payment and professional-service providers; to organization administrators for organization accounts; to other users when information is public or intentionally shared; to integration providers at user direction; in corporate transactions; and when required to comply with law or protect rights, safety and security.'),
  ('No Sale of Personal Information / Targeted Advertising Position','Sports Terminal should adopt a launch policy not to sell personal information for money. If future advertising, cross-context behavioral advertising, sharing or targeted-advertising practices fall within regulated definitions, this Policy and preference controls must be updated before deployment and applicable opt-out rights must be honored.'),
  ('Data Retention','We retain information for as long as reasonably necessary for the purposes described, including while an account is active, for contractual and legal obligations, security, fraud prevention, dispute resolution, auditability and backup integrity. Retention schedules should distinguish account data, community content, messages, security logs, billing records, enterprise data, support records and deidentified analytics.'),
  ('Security','We use administrative, technical and physical safeguards appropriate to risk, including access controls, least privilege, authentication protections, encryption in transit, secure credential handling, logging, monitoring, vulnerability management, backups, incident response and vendor review. No system is perfectly secure; users are responsible for protecting credentials and promptly reporting suspected compromise.'),
  ('Children and Age Restrictions','The public launch should specify a minimum account age based on intended audience and applicable law. The Services are not intended to knowingly collect personal information from children below the stated minimum age without legally valid authorization. If we learn that prohibited child data was collected, we will take appropriate steps to delete or otherwise address it.'),
  ('Your Choices','Users may manage profile visibility, favorite teams, follows, alerts, email preferences, community relationships, certain analytics choices, connected integrations and other settings. Marketing communications should include unsubscribe mechanisms. Necessary service and security communications may still be sent.'),
  ('Privacy Rights','Depending on location, users may have rights to access, know, correct, delete, port or obtain copies of personal information; object to or restrict processing; withdraw consent; opt out of certain sales, sharing, profiling or targeted advertising; limit certain sensitive-data uses; and appeal privacy-request decisions. We will verify requests as required and may deny or limit requests where law permits.'),
  ('California and U.S. State Privacy Disclosures','Where applicable, Sports Terminal will provide notices describing categories of personal information collected, sources, purposes, categories of recipients, retention criteria and state-specific rights. We will honor legally recognized opt-out preference signals where required and will not discriminate against users for exercising privacy rights.'),
  ('International Transfers','Information may be processed in countries other than where a user resides. Where required, we will implement valid transfer mechanisms and supplementary safeguards, such as approved contractual clauses, adequacy mechanisms or other lawful transfer tools.'),
  ('Data Deletion and Account Closure','Account deletion should initiate removal or de-identification of account data subject to lawful retention exceptions. Public posts may be deleted, anonymized or retained where necessary to preserve conversation integrity depending on product policy. Organization-controlled data may be subject to the customer agreement and administrator controls.'),
  ('Deidentified and Aggregated Information','We may create aggregated or deidentified information for analytics, product development, research, reporting and security. We should maintain reasonable measures designed to prevent reidentification where required by law and not attempt to reidentify data treated as deidentified except for permitted validation or security purposes.'),
  ('Legal Requests and Safety','We may preserve, access or disclose information when reasonably necessary to comply with valid legal process, enforce agreements, investigate fraud or abuse, protect users or the public, defend legal claims, or protect Sports Terminal property, rights and security. We will evaluate requests consistent with applicable law.'),
  ('Changes to this Policy','We may update this Policy as the product, laws and business practices evolve. Material changes should be communicated through appropriate notices and, where required, renewed consent. The effective and last-updated dates will identify the operative version.'),
  ('Contact','Privacy questions and rights requests should be directed to [privacy@sportsterminal.com placeholder] or the legal mailing address to be added before launch. Jurisdiction-specific representative or data-protection-officer details will be listed where required.'),
];

const _termsSections = <(String,String)>[
  ('Agreement and Eligibility','These Terms form a binding agreement between the user and Sports Terminal [legal entity placeholder]. You represent that you have legal capacity to enter this agreement and meet the minimum account age. If you use the Services for an organization, you represent that you are authorized to bind or act for that organization to the extent applicable.'),
  ('Account Registration and Legal Acceptance','An account may not be created unless the user affirmatively accepts the then-current Terms and Privacy Policy. Users must provide accurate information, maintain account security, keep credentials confidential, promptly report suspected unauthorized access and remain responsible for activity performed through their account except where law provides otherwise.'),
  ('Services and Product Evolution','Sports Terminal may provide sports data, statistics, historical databases, analytical tools, research workspaces, trade and roster modeling, articles, community features, messaging, fantasy tools, alerts, APIs and other products. Features may change, be added, removed, restricted, suspended or designated beta as the platform develops.'),
  ('No Affiliation or Endorsement','Unless expressly stated, Sports Terminal is an independent product and is not affiliated with, endorsed by, sponsored by or officially connected to the NBA, WNBA, NFL, MLB, NHL, NCAA, FIFA, UEFA, MLS, teams, players, unions, media companies or other leagues and rights holders. Third-party names, marks and data remain the property of their respective owners.'),
  ('Subscriptions, Fees, Taxes and Renewal','Paid features may require a subscription or other fee. Pricing, billing frequency, included features, trial terms, renewal mechanics and cancellation rights will be disclosed at purchase. Users authorize applicable charges and are responsible for taxes except where Sports Terminal is required to collect them. Refund rights are governed by purchase terms and applicable law.'),
  ('Sports Data and Source Limitations','Sports data may originate from public sources, licensed providers, official feeds, historical datasets, calculations and models. Data can contain errors, latency, omissions, revisions or source conflicts. Sports Terminal may correct or replace data and does not warrant that every statistic, transaction, contract, injury, roster, schedule, projection or historical record is complete or error-free.'),
  ('Analytics, Models and AI Outputs','Rankings, projections, impact metrics, valuations, trade analysis, recommendations, simulations, AI summaries and other modeled outputs are informational tools. They may rely on assumptions and probabilistic methods and can be wrong. Users must independently evaluate decisions and should not treat outputs as guarantees, official league determinations or substitutes for qualified professional advice.'),
  ('Trade Machine and CBA Tools','Trade, salary-cap, apron, roster, contract and draft tools are simulations. A scenario shown as passing product checks is not official approval by a league or union. Collective bargaining rules, contract terms, timing restrictions, medical information, trade bonuses, consent rights, exceptions and league interpretations may affect legality. Final transaction decisions require authoritative review.'),
  ('No Gambling, Investment, Legal, Tax or Employment Advice','Unless a separately licensed service expressly states otherwise, Sports Terminal does not provide gambling, investment, legal, tax, accounting, medical, employment or agent advice. Sports information and models are not recommendations to wager, buy or sell securities, enter contracts or make other regulated decisions.'),
  ('User Content License','You retain ownership of content you create, subject to rights needed to operate the Services. By posting or submitting content, you grant Sports Terminal a worldwide, non-exclusive, royalty-free license to host, store, reproduce, format, display, distribute and technically adapt that content for operating, promoting and improving the Services, subject to privacy settings and applicable law. Additional terms may apply to paid or commissioned editorial work.'),
  ('User Representations for Content','You represent that you have the rights necessary to submit content and that it does not unlawfully infringe copyright, trademark, privacy, publicity, contractual, confidentiality or other rights; contain unlawful material; impersonate others; or violate these Terms or Community Rules.'),
  ('Sports Terminal Intellectual Property','The Services, software, interfaces, workflows, visual design, databases, taxonomy, original metrics, models, source code, documentation, trademarks, logos, editorial works and other Sports Terminal materials are owned by Sports Terminal or its licensors and are protected by intellectual-property and other laws. No rights are granted except the limited right to use the Services under these Terms.'),
  ('Restrictions on Copying and Competitive Use','Except as expressly permitted in writing or by law, users may not copy, reproduce, republish, mirror, frame, scrape, crawl, bulk-download, reverse engineer, decompile, extract, create substitute datasets from, resell, sublicense, commercialize or use the Services or substantial outputs to train or improve a competing product or model. Normal browser indexing expressly authorized by Sports Terminal and approved API use are excluded from this restriction.'),
  ('API and Automated Access','Automated access is prohibited unless provided through an authorized API, documented export or written agreement. API credentials are confidential, rate limits and usage restrictions apply, and Sports Terminal may suspend abusive or security-threatening access. API data may carry additional source-specific licensing restrictions.'),
  ('Acceptable Use','Users may not use the Services for unlawful activity, harassment, threats, hate, exploitation, doxxing, non-consensual intimate content, fraud, spam, malicious automation, credential attacks, malware, security testing without authorization, evasion of sanctions, manipulation of engagement systems, impersonation, deceptive coordinated activity or interference with platform operation.'),
  ('Community Rules and Moderation','Sports Terminal may establish Community Rules and moderate posts, comments, messages, profiles and other content. We may remove content, reduce distribution, issue warnings, restrict features, suspend or terminate accounts and preserve evidence. Moderation systems can make mistakes; appeals may be offered. No moderation policy creates a duty to monitor every item of user content.'),
  ('Private Messages and Safety','Messaging is intended for lawful communication among authorized users. Users must respect blocks, mutes, privacy and consent. Sports Terminal may use automated and human review mechanisms as permitted by law to detect abuse, threats, fraud, malware or other policy violations and may act on reports.'),
  ('Organization Accounts','Organization administrators may invite/remove members, assign roles, control organization resources, access organization-visible content and manage settings. Users understand that content created in an organization workspace may be controlled by the organization under its agreement. Conflicts between these Terms and a signed enterprise agreement are resolved as specified in that agreement.'),
  ('Confidentiality and Professional Work','Users must not upload confidential, proprietary, personal or regulated information unless authorized to do so and the applicable Sports Terminal product is approved for that data. Beta and consumer features should not be assumed to satisfy specialized compliance requirements unless expressly stated in a written agreement.'),
  ('Third-Party Services and Links','The Services may link to or interoperate with third-party products, sites and datasets. Sports Terminal does not control third-party services and is not responsible for their availability, content, security or practices. Third-party terms and privacy policies govern those services.'),
  ('Copyright and Rights Complaints','Sports Terminal will maintain a process for copyright, trademark, privacy and other rights complaints. Valid notices should identify the work or right claimed, the challenged material, contact information, a good-faith statement and other legally required elements. Repeat-infringer policies may apply where required.'),
  ('Feedback','If you provide product ideas, suggestions or feedback, you grant Sports Terminal the right to use that feedback without restriction or compensation, unless a written agreement says otherwise. This does not transfer ownership of separate confidential materials clearly governed by another agreement.'),
  ('Beta, Experimental and Preview Features','Beta, preview, research and experimental features may be incomplete, unstable, changed without notice and subject to additional limitations. They should not be relied on for mission-critical decisions unless specifically approved for production use.'),
  ('Service Availability','We aim for reliable service but do not guarantee uninterrupted, secure or error-free operation. Maintenance, provider outages, attacks, data-source changes, emergencies or other events may interrupt access. We may impose usage limits or suspend features to protect the platform and users.'),
  ('Suspension and Termination','Sports Terminal may suspend or terminate access for material Terms violations, security risk, fraud, nonpayment, unlawful use, repeated abuse, intellectual-property violations or other legitimate reasons. Users may close accounts subject to applicable cancellation and retention terms. Provisions that by nature should survive termination will survive.'),
  ('Disclaimers','TO THE MAXIMUM EXTENT PERMITTED BY LAW, THE SERVICES ARE PROVIDED “AS IS” AND “AS AVAILABLE.” SPORTS TERMINAL DISCLAIMS IMPLIED WARRANTIES INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, NON-INFRINGEMENT AND WARRANTIES ARISING FROM COURSE OF DEALING. NOTHING IN THESE TERMS EXCLUDES WARRANTIES THAT CANNOT LEGALLY BE DISCLAIMED.'),
  ('Limitation of Liability','TO THE MAXIMUM EXTENT PERMITTED BY LAW, SPORTS TERMINAL AND ITS AFFILIATES, OFFICERS, EMPLOYEES, CONTRACTORS AND LICENSORS WILL NOT BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY OR PUNITIVE DAMAGES, LOST PROFITS, LOST DATA, LOST BUSINESS OR SUBSTITUTE SERVICES. ANY AGGREGATE LIABILITY CAP MUST BE FINALIZED BY COUNSEL AND CONSPICUOUSLY STATED, SUBJECT TO NON-WAIVABLE CONSUMER RIGHTS.'),
  ('Indemnification','To the extent permitted by law, users agree to defend, indemnify and hold harmless Sports Terminal and its affiliates from third-party claims arising from the user’s unlawful conduct, content, misuse of the Services, infringement of third-party rights or material violation of these Terms. Consumer-law limitations and organization-specific allocations of risk may apply.'),
  ('Governing Law and Disputes','The governing law, venue, arbitration provisions, class-action waiver if used, small-claims option, informal dispute process and opt-out mechanics must be selected and finalized with counsel based on the company legal entity and launch jurisdictions. No placeholder dispute term should be treated as operative until finalized.'),
  ('Export Controls and Sanctions','Users may not access or use the Services in violation of applicable export-control, trade-sanctions or anti-boycott laws. Sports Terminal may restrict access where required for legal compliance.'),
  ('Changes to Terms','We may update these Terms as the Services and law evolve. Material changes will be communicated as required. Continued use after an effective update may constitute acceptance where legally permitted; renewed affirmative consent will be obtained where required.'),
  ('Entire Agreement, Severability and Assignment','These Terms, the Privacy Policy, incorporated policies and applicable order forms constitute the agreement for the covered Services unless another signed agreement controls. If a provision is unenforceable, the remainder remains effective to the extent permitted. Users may not assign rights without consent; Sports Terminal may assign in connection with corporate transactions or as otherwise permitted by law.'),
  ('Contact','Legal notices should be sent to [legal@sportsterminal.com placeholder] and the legal mailing address to be added before launch. Support questions should use the Contact page. Formal notices may require specific delivery methods under enterprise agreements.'),
];

class _AboutPage extends StatelessWidget {
  const _AboutPage();
  @override
  Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Hero('ABOUT SPORTS TERMINAL','The operating system for professional sports','Sports Terminal is being built as a unified sports data, research, transaction, publishing and community platform—starting with the NBA and designed to expand across the professional sports ecosystem.'),
    SizedBox(height: 12),
    _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle('What we are building'), SizedBox(height: 8), Text('The platform combines deep historical and current data, linked player/team/game entities, statistics, advanced research, roster and cap tools, trade modeling, workspaces, Python analysis, editorial, team publications, community, messaging and organization workflows in one product.', style: TextStyle(color: _cMuted, height: 1.55)),
      SizedBox(height: 16), _SectionTitle('NBA first'), SizedBox(height: 8), Text('The NBA is the proving ground. The product should reach professional-grade completeness for NBA data and workflows before the same platform architecture expands to additional leagues and sports.', style: TextStyle(color: _cMuted, height: 1.55)),
      SizedBox(height: 16), _SectionTitle('Company details'), SizedBox(height: 8), Text('[Legal company name] · [Headquarters] · [Founding year] · [Leadership/team bios] · [Press contact] · [Careers link] · [Investor/partner contact]. These fields remain placeholders until the company structure is finalized.', style: TextStyle(color: _cAmber, height: 1.55)),
    ])),
  ]);
}

class _ContactPage extends StatelessWidget {
  const _ContactPage();
  @override
  Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Hero('CONTACT','Get in touch with Sports Terminal','Support, enterprise, media, data partnerships, legal and privacy inquiries should each route to the right operating queue.'),
    SizedBox(height: 12),
    _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ContactRow('Customer Support','support@sportsterminal.com','Account access, billing, product help and bug reports.'),
      _ContactRow('Enterprise & Teams','enterprise@sportsterminal.com','Teams, leagues, agencies, media, institutional and organization deployments.'),
      _ContactRow('Data Partnerships','data@sportsterminal.com','Official feeds, licensing, vendors, research partners and source questions.'),
      _ContactRow('Editorial','editorial@sportsterminal.com','Writers, story pitches, corrections, press and content partnerships.'),
      _ContactRow('Privacy','privacy@sportsterminal.com','Privacy questions and data-rights requests.'),
      _ContactRow('Legal','legal@sportsterminal.com','Formal legal notices, IP issues and rights complaints.'),
      _ContactRow('Security','security@sportsterminal.com','Responsible security disclosures and suspected compromise.'),
      SizedBox(height: 10), Text('PLACEHOLDERS: production email domains, mailing address, support hours, response targets and company telephone number must be confirmed before launch.', style: TextStyle(color: _cAmber, height: 1.5, fontWeight: FontWeight.w700)),
    ])),
  ]);
}

class _Hero extends StatelessWidget {
  const _Hero(this.eyebrow,this.title,this.body); final String eyebrow,title,body;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity,padding: const EdgeInsets.all(24),decoration: BoxDecoration(color:_cPanel,border:Border.all(color:_cLine)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(eyebrow,style:const TextStyle(color:_cBlue,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1)),const SizedBox(height:8),Text(title,style:const TextStyle(color:_cText,fontSize:31,fontWeight:FontWeight.w900)),const SizedBox(height:8),ConstrainedBox(constraints:const BoxConstraints(maxWidth:980),child:Text(body,style:const TextStyle(color:_cMuted,height:1.5,fontSize:14)))]));
}
class _Surface extends StatelessWidget { const _Surface({required this.child}); final Widget child; @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_cPanel,border:Border.all(color:_cLine)),child:child); }
class _SectionTitle extends StatelessWidget { const _SectionTitle(this.text); final String text; @override Widget build(BuildContext context)=>Text(text,style:const TextStyle(color:_cText,fontSize:20,fontWeight:FontWeight.w900)); }
class _LegalSection extends StatelessWidget { const _LegalSection({required this.number,required this.title,required this.body}); final int number; final String title,body; @override Widget build(BuildContext context)=>_Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$number. $title',style:const TextStyle(color:_cText,fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:7),Text(body,style:const TextStyle(color:_cMuted,height:1.6,fontSize:13))])); }
class _LeadStory extends StatelessWidget { const _LeadStory({required this.story}); final (String,String,String,String) story; @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:_cPanel2,border:Border.all(color:_cLine)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${story.$1} · ${story.$4}'.toUpperCase(),style:const TextStyle(color:_cBlue,fontSize:10,fontWeight:FontWeight.w900)),const SizedBox(height:9),Text(story.$2,style:const TextStyle(color:_cText,fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(story.$3,style:const TextStyle(color:_cMuted,height:1.5,fontSize:14)),const SizedBox(height:12),const Text('READ STORY →',style:TextStyle(color:_cAmber,fontWeight:FontWeight.w900))])); }
class _StoryCard extends StatelessWidget { const _StoryCard({required this.story}); final (String,String,String,String) story; @override Widget build(BuildContext context)=>_Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${story.$1} · ${story.$4}'.toUpperCase(),style:const TextStyle(color:_cBlue,fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(story.$2,style:const TextStyle(color:_cText,fontSize:18,height:1.2,fontWeight:FontWeight.w900)),const SizedBox(height:7),Text(story.$3,maxLines:4,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_cMuted,height:1.4)),const SizedBox(height:10),const Text('ANALYSIS →',style:TextStyle(color:_cAmber,fontSize:10,fontWeight:FontWeight.w900))])); }
class _ContactRow extends StatelessWidget { const _ContactRow(this.label,this.email,this.body); final String label,email,body; @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:180,child:Text(label,style:const TextStyle(color:_cText,fontWeight:FontWeight.w900))),SizedBox(width:240,child:Text(email,style:const TextStyle(color:_cBlue,fontWeight:FontWeight.w800))),Expanded(child:Text(body,style:const TextStyle(color:_cMuted,height:1.4)))])); }
