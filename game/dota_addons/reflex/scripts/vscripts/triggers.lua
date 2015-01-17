function trig(trigger)
	print('==============')
	print("Triggered")
	PrintTable(trigger)
	print('--------------')
	PrintTable(trigger.activator)
	print('--------------')
	print('--------------')
	PrintTable(trigger.caller)
	print('--------------')
	PrintTable(getmetatable(trigger.caller))
	print('--------------')
	print('==============')
	print('')
	print('')

	print(trigger.caller:GetName())
	print(trigger.caller:GetClassname())
	print(trigger.caller:GetDebugName())

	
end
