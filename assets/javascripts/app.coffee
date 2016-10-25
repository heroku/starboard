root = exports ? this
root.starboard = {}

# For setting the start date formfield value to today
Date.prototype.toDateInputValue = ->
  local = new Date(this)
  local.setMinutes(this.getMinutes() - this.getTimezoneOffset())
  local.toJSON().slice(0,10)

String.prototype.capitalize = ->
  this[0].toUpperCase() + this[1..-1].toLowerCase()

# Trello Promises
Trello.postAsync = (path, data) ->
  Promise.resolve(Trello.post(path, data))

Trello.getAsync = (path) ->
  Promise.resolve(Trello.get(path))

Trello.putAsync = (path, data) ->
  Promise.resolve(Trello.put(path, data))

Trello.organizations.getAsync = (org_name) ->
  Promise.resolve(Trello.organizations.get(org_name))

$.getJSONAsync = (path) ->
  Promise.resolve($.getJSON(path))

$.getAsync = (path) ->
  Promise.resolve($.get(path))

initChosen = ->
  $('select').each((index) ->
    $(this).chosen({width: "100%"})
    this.setAttribute(
      'style', 'display:visible; position:absolute; clip:rect(0,0,0,0)'))

authorize = (interactive = false) ->
  log.debug("Authorize: %o", interactive)
  Trello.authorize({
    type: 'redirect',
    name: "#{root.starboard.org_name.capitalize()} Starboard",
    interactive: interactive,
    scope: {read: true, write: true, account: false}
    expiration: 'never',
    success: onAuthorize,
    error: ->
      log.warn("Trello auth failed, retrying with interactive=True")
      authorize(true)
  })


onAuthorize = ->
  log.debug("onAuthorize")
  Trello.organizations.getAsync(root.starboard.org_name)
  .then((org) ->
    log.debug("able to get #{root.starboard.org_name} org", org)
    root.starboard.org = org
    setup())
  .catch((err) ->
    log.debug("unable to get #{root.starboard.org_name} org", err)
    Trello.deauthorize()
    authorize(true)
  )

prepareForm = (data) ->
  tree = new TreeModel()
  root.starboard.teams = tree.parse(data)
  teamnames = _.map(root.starboard.teams.all(-> true), (team) ->
    {"name": team.model.id, "slug": team.model.slug}
  )
  $('.controls').append ich.controls
    'teams': teamnames,
    'onboarding_sources': (starboard.information.onboarding_sources || [])
    'options': (starboard.information.options || [])
  $('#date').val(new Date().toDateInputValue())

  # hacky workaround to enable HTML5 Validation errors to appear with chosen
  $('select').each((index) ->
    $(this).chosen({width: "100%"})
    this.setAttribute(
      'style', 'display:visible; position:absolute; clip:rect(0,0,0,0)')
  )

  $('form').on('submit', onCreate)


# Once we've authorized with trello
setup = (retry_count)->
  log.debug("setup")

  retry_count ||= 3

  # Get the team map
  $.getJSONAsync('guides/data.json').then((data) ->
    $("section.loading").addClass("hidden")
    root.starboard.information = data
    prepareForm(data["teams"])
  ).catch( ->
    $("section.loading").removeClass("hidden")
    # If we fails, refresh guides and retry
    $.post("/guides?t=#{starboard.token}", ->
      setup(retry_count - 1)
    )
  )


showProgress = () ->
  $('input.button').hide()
  $('.working').removeClass('hidden')


# TODO: cleanup the board.
abortCreation = (reason, error) ->
  alert(reason)
  $('input.button').show()
  $('.working').addClass('hidden')
  # Reset progress
  root.starboard.progress = 0
  log.error(reason)
  log.error(error)


pathsForTeam = (team, boardingType) ->
  if boardingType == "" || boardingType == undefined
    boardingType = "onboarding"
  # get the team and all nodes above it in the tree
  teamnode = root.starboard.teams.first((node) ->
    node.model.slug == team)
  relevant = teamnode.getPath()
  # figure out which guides to render
  paths = []
  additional_paths = []
  _.each(relevant, (n, index, list) ->
    if index == 0
      paths.push("/#{n.model.slug}")
    else
      paths.push("#{paths[-1..]}/#{n.model.slug}")

    if 'additional_paths' of n.model
      additional_paths = additional_paths.concat(n.model.additional_paths)
  )
  paths = _.uniq(paths.concat(additional_paths))
  log.debug("Deduped Paths: %o", paths)
  paths = _.map(paths, (p) -> "/guides#{p}/#{boardingType}.markdown" )


# Someone hit the "create" button.
# TODO Validation only works on modern browsers. Should lock older ones out.
onCreate = (event) ->
  log.debug("Form submitted.")
  showProgress()
  formdata = getValues()

  # Get all the docs, render and merge the lists
  promises = _.map(pathsForTeam(formdata.team, formdata.boarding_type), (p) -> $.getAsync(p))
  Promise.settle(promises).then((results) ->
    docs = []
    _.each(results, (result) ->
      if result.isFulfilled()
        docs.push(renderMarkdown(result.value()))
    )
    merged = mergeLists(docs)
    createBoard(merged)
  ).catch((error) ->
    abortCreation("Getting all the docs failed", error)
  )

  event.preventDefault()


# merge document lists with the same name
# e.g. multiple guides with "First Day" list
mergeLists = (docs) ->
  listmap = {}
  _.each(docs, (doc) ->
    _.each(doc, (list) ->
      if list.name of listmap
        # This list already exists, merge in the cards
        # TODO check for identical cards and concat checklists
        listmap[list.name].cards = listmap[list.name].cards.concat(list.cards)
      else
        # It's the first time we're seeing a list with this name
        listmap[list.name] = list
    )
  )
  _.values(listmap)


# Calculate number of items in lists to set max progress.
resetProgress = (lists) ->
  root.starboard.progress = 0

  totalitems = _.reduce(lists, (memo, list) ->
    memo + 1 + _.reduce(list.cards or [], (memo, card) ->
      memo + 1 + _.reduce(card.checklists or [], (memo, checklist) ->
        memo + 1 + (checklist.items.length or 0)
      , 0)
    , 0)
  , 0)

  log.debug("Total #{totalitems} items to render.")
  $('progress').attr('max', totalitems)


# Create the trello board and remove the default lists
createBoard = (lists) ->
  log.debug("Creating board…")
  formdata = getValues()
  root.starboard.formdata = formdata
  resetProgress(lists)

  # create the trello board
  board_opts = {
    "name": "#{formdata.name} • #{formdata.boarding_type.capitalize()} #{formdata.date}",
    "idOrganization": root.starboard.org.id,
    "prefs_permissionLevel": "org",
    "prefs_comments": "org",
    "prefs_selfJoin": true  # TODO can remove the selfjoin
  }

  Trello.postAsync("boards", board_opts)
  .then(initBoard(lists))
  .catch((error) -> abortCreation("Unable to create the board.", error))

initBoard = (lists) ->
  (board) ->
    log.debug("Created board #{board.url}")
    Trello.getAsync("/board/#{board.id}/lists")
    .then(removeLists)
    .then(->
      log.debug("Trello board created and lists removed")
      fillBoard(board, lists))

# remove default lists in a generated board
removeLists = (lists) ->
  log.debug("Removing default lists…")
  promises = _.map(lists, (list) ->
    Trello.putAsync("/lists/#{list.id}/closed", {'value': true})
  )
  # When all of the removal XHRs succeed...
  Promise.all(promises)

# Given an array of lists, sort them regarding the lists_order in information.json
sortedLists = (lists) ->
  _.sortBy(lists, (list) ->
    index = _.indexOf(starboard.information.lists_order, list.name)
    if index == -1
      index = 1000
    index
  )

reorderLists = (board) ->
  Trello.getAsync("/board/#{board.id}/lists")
  .then((trelloLists)->
    promise = new Promise((resolve, error) -> resolve(true))
    _.each(sortedLists(trelloLists), (list) ->
      promise = promise.then(-> Trello.put("/lists/#{list.id}/pos", {"value": "bottom" })))
    promise
  )


# Dream Flow
fillBoard = (trelloBoard, lists) ->
  Promise.map(sortedLists(lists), (list) =>
    Trello.postAsync("/board/#{trelloBoard.id}/lists", {'name': list.name, pos: "bottom" })
    .then((trelloList) ->
      log.debug("Created list '#{list.name}'", trelloList)
      root.starboard.progress += 1
      $('progress').attr('value', root.starboard.progress)
      trelloList.cards = list.cards
      trelloList)
  ).then( (lists) ->
    console.log("lists", lists)
    cards = []
    lists.reduce( (acc, list) ->
      acc.then( -> Promise.all(createCards(list)))
         .then( (listCards) -> cards = cards.concat(listCards))
    , Promise.resolve()).then(-> cards)
  ).then((cards) ->
    console.log("cards", cards)
    checkLists = []
    cards.reduce( (acc, card) ->
      acc.then(-> Promise.all(createCheckLists(card)))
         .then((cardLists) -> checkLists =  checkLists.concat(cardLists))
    , Promise.resolve()).then(-> checkLists)
  ).then((checkLists) ->
    console.log("checkLists", checkLists)
    items = []
    checkLists.reduce( (acc, list) ->
      acc.then(-> Promise.all(createCheckItems(list)))
         .then((listItems) -> items = items.concat listItems)
    , Promise.resolve()).then(-> Promise.all(items))
  ).then(->
    log.debug("Ordering the lists", lists)
    reorderLists(trelloBoard)
  ).then(->
    log.debug("Done building board: #{trelloBoard.url}")
    window.location.href = trelloBoard.url
  ).catch((error) ->
    abortCreation("Unable to build board!", error)
  )

getExpectedDate = (string) ->
  expectedDateMatch = /(+|-)(\d+)d/.exec(string)
  unless expectedDateMatch == null
    today = new Date()
    if expectedDateMatch[1] == "+"
      today.setDate(today.getDate() + parseInt(expectedDateMatch[2]))
    if expectedDateMatch[1] == "-"
      today.setDate(today.getDate() - parseInt(expectedDateMatch[2]))
    today

createCards = (list) ->
  _.map(list.cards, (card, index) ->
    name = card.name.replace(/\[(.*)\]/, '')
    tags = card.name.replace(/([^\[]*)(\[(.*)\])?/, '$3').split(" ").filter((e) -> e)
    tags = _.map(tags, (t) -> t.toLowerCase())
    expectedDate = getExpectedDate(card.name)
    # SKIP if if choosen tags are not covering the ones for this card
    if _.difference(tags, root.starboard.formdata.tags).length != 0
      log.info("skipped",name, tags)
      return
    else
      Trello.postAsync("/lists/#{list.id}/cards",
          { 'name': name, 'desc': card.description, 'pos': index, 'due': expectedDate })
      .then((trelloCard) ->
        log.debug("Created card '#{name}'")
        root.starboard.progress += 1
        $('progress').attr('value', root.starboard.progress)
        trelloCard.checklists = card.checklists
        trelloCard
      ).catch((reason) ->
        log.error("Unable to create card '#{name}")
      )
  )

createCheckLists = (card) ->
  _.map(card.checklists, (checklist, index) ->
    name = checklist.name.replace(/\[(.*)\]/, '')
    tags = checklist.name.replace(/([^\[]*)(\[(.*)\])?/, '$3').split(" ").filter((e) -> e)
    tags = _.map(tags, (t) -> t.toLowerCase())
    if tags.length > 0
      log.info("has many tags", tags)
    # SKIP if if choosen tags are not covering the ones for this card
    if _.difference(tags, root.starboard.formdata.tags).length != 0
      log.info("skipped",name, tags)
      return
    else
      Trello.postAsync("/cards/#{card.id}/checklists",
        { "value": null, "name": name, 'pos': index })
      .then((trelloChecklist) ->
        log.debug("Created checklist '#{name}'")
        root.starboard.progress += 1
        $('progress').attr('value', root.starboard.progress)
        trelloChecklist.items = checklist.items
        trelloChecklist
      ).catch((reason) ->
        log.error("Unable to create checklist '#{name}")
      )
  )

createCheckItems = (checklist) ->
  _.map(checklist.items, (item, index) ->
    Trello.postAsync("/checklists/#{checklist.id}/checkItems",
                  { "name": item, 'pos': index })
      .then((checkItem) ->
        log.debug ("Created checkItem '#{item}'")
        root.starboard.progress += 1
        $('progress').attr('value', root.starboard.progress)
      ).catch(-> log.error("Unable to create checkItem '#{item}"))
  )


# JSONify raw markdown
renderMarkdown = (rawmd) ->
  renderer = new marked.Renderer()
  data_structure = []
  current_list = {}
  current_card = {}
  current_checklist = {}

  renderer.heading = (text, level) ->
    if level == 1
      current_list = { name: text, cards: []}
      data_structure.push(current_list)
    else if level == 2
      current_card = { name: text, checklists: [], description: '' }
      current_list.cards.push(current_card)
    else if (level == 3)
      current_checklist = { name: text, items: [] }
      current_card.checklists.push(current_checklist)
    text

  renderer.html = (text) ->
    text

  renderer.paragraph = (text) ->
    current_card.description = current_card.description + text + "\n\n"
    text

  renderer.listitem = (text, list_type) ->
    current_checklist.items.push(text)
    text

  renderer.strong = (text) ->
    "**#{text}**"

  renderer.em = (text) ->
    "_#{text}_"

  renderer.link = (href, title, text) ->
    "[#{text}](#{href})"

  renderer.codespan = (code) ->
    "`#{code}`"

  marked(rawmd, {renderer: renderer})
  log.debug(marked.lexer(rawmd, {renderer: renderer}))
  log.debug(data_structure)
  data_structure


# Get the values from the form fields
getValues = ->
  boarding_type = $("#boarding-type").val().split("-")[0]
  recruiting_source = $("#boarding-type").val().split("-")[1]
  options = _.map($("[name='options[]']:checked"), (e) ->
    $(e).val()
  )

  {
    "name": $("#name").val(),
    "date": $("#date").val(),
    "team": $("#team-name").val(),
    "work_site": $("#work-site").val(),
    "employment_mode": $("#employment-mode").val(),
    "recruiting_source": recruiting_source,
    "boarding_type": boarding_type,
    "options": options,
    "tags": _.union([recruiting_source], options),
  }

$ ->
  log.enableAll()
  log.debug("domready")
  root.starboard.org_name = $('body').data('organization')
  root.starboard.token    = $('body').data('token')
  authorize(false)
