{each, map, id, find, lists-to-obj, fold, values, filter} = require \prelude-ls

$ ->
	window.media-source-tree =
		containerElement: $('#sources')	
		parentPrefix: 'i.'

		create: (results)->
			self = @

			formatedData = results 
				|> map -> it.split("|")
				|> fold (m, v)->
				
					if m[v[0]] == undefined
						m[v[0]] = 
							text: v[0] 

					
					if v[1].length == 0
						m[v[0]].id = "#{v[0]}|"
						return m

					if m[v[0]].children == undefined
						m[v[0]]
							..children = []					
							..id = "i.#{v[0].replace(/\s+/g, '').toLowerCase()}"

					m[v[0]].children.push(text: v[1], id: "#{v[0]}|#{v[1]}", icon: "")
					
					return m
				, {}
				|> values

			@containerElement.jstree(
				plugins: [
					"wholerow"
					"checkbox"
				]
				core: 
					themes:
						icons: false
					data: 
						text: "media sources",
						id: 'i.mediasources',
						state:
							opened: true
						children: formatedData
			)


			console.log formatedData
			@containerElement.on 'ready.jstree', -> self.containerElement.jstree('select_all')

		getSelectedSources: ->
			self = @
			selected =  @containerElement.jstree 'get_selected'

			selected = filter ->
				if it.indexOf(self.parentPrefix) != 0
					true
			, selected

			return selected