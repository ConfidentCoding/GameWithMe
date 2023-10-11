local Pagination = {}
Pagination.__index = Pagination

function Pagination.new(api, recordObjectFactory, payload)
	local self = setmetatable({
		api = api;
		recordObjectFactory = recordObjectFactory;
		payload = payload;
		page       = payload["page"];
		perPage    = payload["perPage"];
		pageCount  = payload["pageCount"];
		totalCount = payload["totalCount"];
		objects = {};
	}, Pagination)
	self:loadRecordsFromPayload()
	return self
end

function Pagination:__tostring()
	return ("<Pagination(pg. %d/%d)>"):format(self.page, self.pageCount)
end

function Pagination:loadRecordsFromPayload()
	for i, recordPayload in ipairs(self.payload["records"]) do
		self.objects[i] = self.recordObjectFactory(self.api, recordPayload)
	end
end

function Pagination:getRecordObjects()
	return self.objects
end

return Pagination
